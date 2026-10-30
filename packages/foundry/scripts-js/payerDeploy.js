import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { ethers } from "ethers";
import toml from "toml";
import "dotenv/config";
import { askHuman, canSkipConfirmation, checksum, parsePayerDeployArgs, priceGas, rpcHost } from "./payerDeployGate.js";

// The payer runs this from its own wallet. Signing is by `--account` (encrypted keystore) or `--ledger`;
// forge and cast prompt for the keystore password themselves, so nothing secret passes through this file.
// See docs/implementation/payer-deploy.md.

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const SCRIPT = "script/DeployPayerCampaign.s.sol";
const SCRIPT_FOLDER = "DeployPayerCampaign.s.sol";
const OP_STACK_CHAINS = [8453, 84532];
const GAS_PRICE_ORACLE = "0x420000000000000000000000000000000000000F";
// Chainlink ETH / USD on Base mainnet (8 decimals). description() is checked to read "ETH / USD" before use.
const BASE_ETH_USD_FEED = "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70";
const MAX_FEED_AGE_SECONDS = 3600;

const env = { ...process.env, PATH: `${homedir()}/.foundry/bin:${process.env.PATH ?? ""}` };
// A raw key must never reach forge or cast through this driver.
delete env.PRIVATE_KEY;
delete env.ETH_PRIVATE_KEY;

function capture(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: ROOT, env, encoding: "utf8" });
  if (r.status !== 0) throw new Error(`${cmd} ${args[0]} failed: ${(r.stderr || r.stdout).trim().split("\n").pop()}`);
  return r.stdout.trim();
}

function inherit(cmd, args, extraEnv = {}) {
  const r = spawnSync(cmd, args, { cwd: ROOT, env: { ...env, ...extraEnv }, stdio: "inherit" });
  if (r.status !== 0) throw new Error(`${cmd} ${args.slice(0, 2).join(" ")} exited with ${r.status}`);
}

/** The first word of a `cast call` line, so `1 [1e0]` and `"USDC"` both read cleanly. */
const first = (text) => text.split("\n")[0].split(" ")[0].replaceAll('"', "");

/**
 * Only a foundry.toml alias (keys stay in .env) or a loopback URL is accepted, so an RPC key never has to appear
 * on a command line or in this process's output.
 */
function resolveNetwork(network) {
  if (/^https?:\/\//.test(network)) {
    const url = new URL(network);
    if (!["127.0.0.1", "localhost", "[::1]"].includes(url.hostname)) {
      throw new Error("Pass a foundry.toml rpc_endpoints alias (for example base), not a remote URL, so no RPC key is typed.");
    }
    return { rpcArg: network, rpcUrl: network };
  }
  const endpoints = toml.parse(readFileSync(resolve(ROOT, "foundry.toml"), "utf8")).rpc_endpoints ?? {};
  const raw = endpoints[network];
  if (!raw) throw new Error(`No rpc_endpoints alias "${network}" in foundry.toml`);
  const rpcUrl = raw.replace(/\$\{(\w+)\}/g, (_, name) => {
    if (!process.env[name]) throw new Error(`${name} is not set (put it in .env, never in a committed file)`);
    return process.env[name];
  });
  return { rpcArg: network, rpcUrl };
}

function signerFlags(signer, payer) {
  if (signer.kind === "account") return ["--account", signer.name, "--sender", payer];
  if (signer.kind === "ledger") return ["--ledger", "--sender", payer];
  return ["--unlocked", "--sender", payer];
}

function broadcastJson(chainId, file) {
  const path = resolve(ROOT, "broadcast", SCRIPT_FOLDER, String(chainId), file);
  return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : null;
}

/** ETH / USD in US cents, only on Base mainnet where a Chainlink feed is known. Otherwise null (show ETH only). */
function ethUsdCents(chainId, rpcArg) {
  if (chainId !== 8453) return null;
  const description = capture("cast", ["call", BASE_ETH_USD_FEED, "description()(string)", "--rpc-url", rpcArg]);
  if (!description.includes("ETH / USD")) throw new Error("The Base ETH / USD feed address does not identify itself as ETH / USD");
  const round = capture("cast", ["call", BASE_ETH_USD_FEED, "latestRoundData()(uint80,int256,uint256,uint256,uint80)", "--rpc-url", rpcArg])
    .split("\n")
    .map(first);
  const answer = BigInt(round[1]);
  const updatedAt = Number(round[3]);
  const now = Number(capture("cast", ["block", "latest", "--field", "timestamp", "--rpc-url", rpcArg]));
  if (now - updatedAt > MAX_FEED_AGE_SECONDS) {
    console.log(`  warning: the ETH / USD price is ${now - updatedAt}s old; the USD figure may be stale`);
  }
  return answer / 1_000_000n; // 8 decimals to cents
}

/** Estimated cost of the transactions forge would send, from a dry run (no signature, no broadcast). */
function estimateDryRun({ sig, chainId, rpcArg, payer, configPath, outPath, gasPriceWei }) {
  rmSync(resolve(ROOT, "broadcast", SCRIPT_FOLDER, String(chainId), "dry-run"), { recursive: true, force: true });
  inherit("forge", ["script", SCRIPT, "--sig", sig, "--rpc-url", rpcArg, "--sender", payer, "-q"], {
    PAYER_CONFIG: configPath,
    PAYER_DEPLOY_OUT: outPath,
  });
  const dry = broadcastJson(chainId, "dry-run/" + (sig.startsWith("run") ? "run" : "fundAndSeed") + "-latest.json");
  const txs = dry?.transactions ?? [];
  let gasUsed = 0n;
  let l1FeeWei = 0n;
  for (const tx of txs) {
    gasUsed += BigInt(tx.transaction.gas);
    if (OP_STACK_CHAINS.includes(chainId)) {
      try {
        l1FeeWei += BigInt(first(capture("cast", ["call", GAS_PRICE_ORACLE, "getL1Fee(bytes)(uint256)", tx.transaction.input ?? tx.transaction.data, "--rpc-url", rpcArg])));
      } catch {
        // The oracle call is only an estimate; the real L1 fee is read from the receipts after sending.
      }
    }
  }
  return { gasUsed, gasPriceWei, l1FeeWei, count: txs.length };
}

/** What was actually paid, from the receipts. The L1 data fee comes from the receipt, not a guess. */
function actualCost({ file, chainId, rpcArg, cents }) {
  const run = broadcastJson(chainId, file);
  const hashes = (run?.receipts ?? []).map((r) => r.transactionHash);
  let gasUsed = 0n;
  let executionWei = 0n;
  let l1FeeWei = 0n;
  let operatorFeeWei = 0n;
  let l1FeeSource = "none (not an OP Stack chain)";
  for (const hash of hashes) {
    const receipt = JSON.parse(capture("cast", ["receipt", hash, "--json", "--rpc-url", rpcArg]));
    const used = BigInt(receipt.gasUsed);
    gasUsed += used;
    executionWei += used * BigInt(receipt.effectiveGasPrice);
    if (OP_STACK_CHAINS.includes(chainId)) {
      if (receipt.l1Fee !== undefined) {
        l1FeeWei += BigInt(receipt.l1Fee);
        l1FeeSource = "receipt l1Fee";
      } else {
        l1FeeSource = "receipt had no l1Fee; not counted";
      }
      if (receipt.operatorFee !== undefined) operatorFeeWei += BigInt(receipt.operatorFee);
    }
  }
  // Each transaction had its own effective gas price, so the summed execution cost is passed as gas x 1 wei.
  const cost = priceGas({ gasUsed: executionWei, gasPriceWei: 1n, l1FeeWei, operatorFeeWei, ethUsdCents: cents });
  return { ...cost, gasUsed, l1FeeSource, count: hashes.length };
}

function showCost(label, cost, gasUsed, note) {
  console.log(`  ${label}: ${gasUsed} gas, ${cost.executionWei} wei execution + ${cost.l1FeeWei} wei L1 data fee + ${cost.operatorFeeWei} wei operator fee`);
  console.log(`    = ${cost.totalEth} ETH${cost.usd === null ? " (no live USD price on this chain)" : ` = about ${cost.usd} USD at the live ETH / USD price`}${note ? ` (${note})` : ""}`);
}

/** `skipRequested` is only ever true after main() proved the chain is a loopback 31337. */
async function confirm(question, skipRequested) {
  if (skipRequested) {
    console.log("  confirmation skipped: local chain only");
    return;
  }
  if (!(await askHuman(question))) throw new Error("Not confirmed. Nothing was sent.");
}

export async function main(argv) {
  const args = parsePayerDeployArgs(argv);
  if (args.help) {
    console.log("yarn payer:deploy --config <settings.json> --network <alias> (--account <name> | --ledger)");
    return;
  }
  const configPath = isAbsolute(args.config) ? args.config : resolve(process.cwd(), args.config);
  const cfg = JSON.parse(readFileSync(configPath, "utf8"));
  const payer = checksum(cfg.payer);
  const { rpcArg, rpcUrl } = resolveNetwork(args.network);
  const chainId = Number(capture("cast", ["chain-id", "--rpc-url", rpcArg]));
  const skippable = canSkipConfirmation({ chainId, rpcUrl });
  if (args.skipConfirmation && !skippable) {
    throw new Error("--skip-confirmation works only on chain 31337 against a loopback RPC. A real payer always confirms.");
  }
  if (args.signer.kind === "local") {
    if (!skippable) throw new Error("--local-sender works only on chain 31337 against a loopback RPC. Use --account or --ledger.");
    if (checksum(args.signer.address) !== payer) throw new Error("--local-sender must be the payer address in the config");
  }
  const outPath = resolve(ROOT, "deployments", `payer-${chainId}.json`);
  const sharedEnv = { PAYER_CONFIG: configPath, PAYER_DEPLOY_OUT: process.env.PAYER_DEPLOY_OUT ?? outPath };
  const out = sharedEnv.PAYER_DEPLOY_OUT;

  console.log(`\nPayer deploy on chain ${chainId} via ${rpcHost(rpcUrl)}`);
  console.log("1. Vetting the pool, factory, fee, stake token and Stake cap (read only)");
  inherit("forge", ["script", SCRIPT, "--sig", "preflight()", "--rpc-url", rpcArg, "-q"], sharedEnv);

  const isEth = BigInt(cfg.stakeToken) === 0n;
  let symbol = "ETH";
  let decimals = 18;
  if (!isEth) {
    symbol = first(capture("cast", ["call", cfg.stakeToken, "symbol()(string)", "--rpc-url", rpcArg]));
    decimals = Number(first(capture("cast", ["call", cfg.stakeToken, "decimals()(uint8)", "--rpc-url", rpcArg])));
  }
  const fmt = (v) => `${ethers.utils.formatUnits(v, decimals)} ${symbol}`;
  const required = BigInt(cfg.updown.funding) + BigInt(cfg.threshold.funding);
  const held = BigInt(
    first(
      isEth
        ? capture("cast", ["balance", payer, "--rpc-url", rpcArg])
        : capture("cast", ["call", cfg.stakeToken, "balanceOf(address)(uint256)", payer, "--rpc-url", rpcArg])
    )
  );
  const gasPriceWei = BigInt(capture("cast", ["gas-price", "--rpc-url", rpcArg]));
  const cents = ethUsdCents(chainId, rpcArg);

  console.log("\nWhat will happen");
  console.log(`  Payer and owner of both contracts: ${payer}`);
  console.log(`  Stake token: ${symbol} ${isEth ? "(ETH)" : checksum(cfg.stakeToken)}`);
  console.log(`  Pool: ${checksum(cfg.pool)} (fee ${cfg.poolFee}), base token ${checksum(cfg.baseToken)}`);
  console.log(`  UpDownRounds  (new, owner ${payer}): fund ${fmt(cfg.updown.funding)}; seed ${fmt(cfg.updown.seed)}; Stake cap ${fmt(cfg.updown.stakeCap)}; trading ${cfg.updown.tradingSeconds}s, Window ${cfg.updown.windowSeconds}s`);
  console.log(`  ThresholdPots (new, owner ${payer}): fund ${fmt(cfg.threshold.funding)}; Opening stake ${fmt(cfg.threshold.openingStake)}; Stake cap ${fmt(cfg.threshold.stakeCap)}; trading ${cfg.threshold.tradingSeconds}s, Window ${cfg.threshold.windowSeconds}s`);
  console.log(`  Total leaving the payer into the two contracts: ${fmt(required)} (payer holds ${fmt(held)})`);
  if (held < required) throw new Error("The payer does not hold enough to fund both Campaigns");

  console.log("\n2. Deploy estimate (a dry run, nothing sent)");
  // The dry run writes its predicted addresses to a scratch file so an earlier real record is never touched.
  const scratchOut = `${out}.estimate`;
  const deployEstimate = estimateDryRun({ sig: "run()", chainId, rpcArg, payer, configPath, outPath: scratchOut, gasPriceWei });
  rmSync(scratchOut, { force: true });
  const deployEstimatePrice = priceGas({ gasUsed: deployEstimate.gasUsed, gasPriceWei, l1FeeWei: deployEstimate.l1FeeWei, ethUsdCents: cents });
  showCost("Estimated deploy of the readers, UpDownRounds and ThresholdPots", deployEstimatePrice, deployEstimate.gasUsed, "gas limit upper bound; the real L1 fee is read from the receipts");
  await confirm("Deploy the contracts from the payer wallet now?", args.skipConfirmation);

  console.log("\n3. Deploying (forge asks for the keystore password or the Ledger approval)");
  inherit("forge", ["script", SCRIPT, "--sig", "run()", "--rpc-url", rpcArg, "--broadcast", "--slow", ...signerFlags(args.signer, payer)], sharedEnv);
  const deployed = JSON.parse(readFileSync(out, "utf8"));
  const deployCost = actualCost({ file: "run-latest.json", chainId, rpcArg, cents });
  console.log("\nDeployed");
  console.log(`  UpDownRounds  ${checksum(deployed.upDown)}`);
  console.log(`  ThresholdPots ${checksum(deployed.threshold)}`);
  console.log(`  BasePoolReader ${checksum(deployed.priceReader)}`);
  showCost("Actual deploy cost", deployCost, deployCost.gasUsed, `L1 data fee from ${deployCost.l1FeeSource}`);
  for (const [name, address] of [["UpDownRounds", deployed.upDown], ["ThresholdPots", deployed.threshold]]) {
    const owner = checksum(first(capture("cast", ["call", address, "owner()(address)", "--rpc-url", rpcArg])));
    if (owner !== payer) throw new Error(`${name} is owned by ${owner}, not the payer ${payer}`);
    console.log(`  ${name} owner is the payer`);
  }

  console.log("\n4. Funding estimate (a dry run, nothing sent)");
  const fundEstimate = estimateDryRun({ sig: "fundAndSeed()", chainId, rpcArg, payer, configPath, outPath: out, gasPriceWei });
  const fundPrice = priceGas({ gasUsed: fundEstimate.gasUsed, gasPriceWei, l1FeeWei: fundEstimate.l1FeeWei, ethUsdCents: cents });
  console.log("  Funds leaving the payer, to checksummed destinations:");
  console.log(`    ${fmt(cfg.updown.funding)} to UpDownRounds  ${checksum(deployed.upDown)}`);
  console.log(`    ${fmt(cfg.threshold.funding)} to ThresholdPots ${checksum(deployed.threshold)}`);
  showCost("Estimated funding and seeding", fundPrice, fundEstimate.gasUsed, "gas limit upper bound");
  const spent = priceGas({
    gasUsed: 1n,
    gasPriceWei: deployCost.executionWei + fundPrice.executionWei,
    l1FeeWei: deployCost.l1FeeWei + fundPrice.l1FeeWei,
    operatorFeeWei: deployCost.operatorFeeWei,
    ethUsdCents: cents,
  });
  console.log(`  Gas for the whole run (deploy actual + funding estimate): ${spent.totalEth} ETH${spent.usd === null ? "" : ` = about ${spent.usd} USD`}`);
  await confirm("Send the funds and start both Campaigns now?", args.skipConfirmation);

  console.log("\n5. Funding and seeding");
  inherit("forge", ["script", SCRIPT, "--sig", "fundAndSeed()", "--rpc-url", rpcArg, "--broadcast", "--slow", ...signerFlags(args.signer, payer)], sharedEnv);
  const fundCost = actualCost({ file: "fundAndSeed-latest.json", chainId, rpcArg, cents });
  showCost("Actual funding and seeding cost", fundCost, fundCost.gasUsed, `L1 data fee from ${fundCost.l1FeeSource}`);

  console.log("\nDone. Next, verify the source right away (these prompt for nothing but the explorer key in .env):");
  console.log(`  VERIFY_SCRIPT=${SCRIPT_FOLDER} yarn verify ${args.network}`);
  console.log("  Sourcify, per contract:");
  const enc = (types, values) => `$(cast abi-encode 'constructor(${types})' ${values.join(" ")})`;
  console.log(`    forge verify-contract ${deployed.upDown} UpDownRounds --chain ${chainId} --verifier sourcify --constructor-args "${enc("address,address,address,uint256", [payer, deployed.priceReader, cfg.stakeToken, cfg.updown.payout])}"`);
  console.log(`    forge verify-contract ${deployed.threshold} ThresholdPots --chain ${chainId} --verifier sourcify --constructor-args "${enc("address,address,address", [payer, deployed.priceReader, cfg.stakeToken])}"`);
  console.log(`    forge verify-contract ${deployed.priceReader} BasePoolReader --chain ${chainId} --verifier sourcify --constructor-args "${enc("address,address,uint32", [cfg.pool, cfg.baseToken, cfg.lookbackSeconds])}"`);
  console.log(`\nSet NEXT_PUBLIC_ROUNDS_ADDRESS=${checksum(deployed.upDown)} and NEXT_PUBLIC_THRESHOLD_ADDRESS=${checksum(deployed.threshold)} for the page, and the same two addresses as SETTLE_UPDOWN_ADDRESS / SETTLE_THRESHOLD_ADDRESS for the settle bot.`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`\nStopped: ${error.message}`);
    process.exit(1);
  });
}

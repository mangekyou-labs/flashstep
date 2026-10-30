// Disposable localhost Anvil fixture. Never reads keys or runs payer deployment scripts.
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { createRequire } from "node:module";
const root = new URL("../", import.meta.url);
const require = createRequire(new URL("packages/nextjs/package.json", root));
const { createPublicClient, createWalletClient, http, parseEther, zeroAddress, isAddress } = require("viem");
const { foundry } = require("viem/chains");
const rpcUrl = process.env.ROUNDS_LOCAL_RPC || "http://127.0.0.1:8545";
if (!["127.0.0.1", "localhost", "[::1]"].includes(new URL(rpcUrl).hostname)) throw new Error("Localhost only.");
const client = createPublicClient({ chain: foundry, transport: http(rpcUrl), pollingInterval: 100 });
const rpc = (method, params = []) => client.request({ method, params });
if (await client.getChainId() !== 31337 || !(await rpc("web3_clientVersion")).toLowerCase().includes("anvil")) throw new Error("Local Anvil required.");
const [payer, other] = await rpc("eth_accounts");
const wallet = createWalletClient({ chain: foundry, transport: http(rpcUrl), account: payer });
const artifact = async name => JSON.parse(await readFile(new URL(`packages/foundry/out/${name === "MockReadingToken" ? "MockBasePool" : name}.sol/${name}.json`, root), "utf8"));
const pots = await artifact("ThresholdPots");
const poolAbi = (await artifact("MockBasePool")).abi;
const stateFile = new URL("output/threshold-local.json", root);
async function receipt(hash) { const r = await client.waitForTransactionReceipt({ hash }); if (r.status !== "success") throw new Error(`Reverted ${hash}`); return r; }
async function deploy(name, args) { const a = await artifact(name); return (await receipt(await wallet.deployContract({ abi: a.abi, bytecode: a.bytecode.object, args, gas: 8_000_000n }))).contractAddress; }
async function write(address, abi, functionName, args = [], value = 0n, account = payer) { return receipt(await wallet.writeContract({ address, abi, functionName, args, value, account, gas: 6_000_000n })); }
async function timestamp(next) { const b = await client.getBlock(); if (b.timestamp >= next) throw new Error(`Boundary passed. Set up a fresh fixture.`); await rpc("evm_setNextBlockTimestamp", [Number(next)]); }
const [command, argument, extra] = process.argv.slice(2);
if (command === "setup") {
  const scenario = argument || "yes";
  if (!["yes", "no", "tie", "unmatched", "marketcap", "usdc"].includes(scenario)) throw new Error("Scenario: yes|no|tie|unmatched|marketcap|usdc");
  await rpc("anvil_setIntervalMining", [0]); await rpc("evm_setAutomine", [true]); await rpc("anvil_setBlockTimestampInterval", [1]);
  const base = await deploy("MockReadingToken", [18, parseEther("1000000")]);
  const quote = await deploy("MockReadingToken", [18, parseEther("1000000")]);
  const pool = await deploy("MockBasePool", [base, quote]);
  await write(pool, poolAbi, "write", [0]);
  const reader = await deploy("BasePoolReader", [pool, base, 4]);
  const capReader = await deploy("MarketCapReader", [reader, 1, parseEther("1000000")]);
  const stakeToken = scenario === "usdc" ? await deploy("QuirkyStakeToken", [6]) : zeroAddress;
  const stakeUnit = scenario === "usdc" ? 1_000_000n : 10n ** 18n;
  const rounds = await deploy("ThresholdPots", [payer, reader, stakeToken]);
  if (stakeToken !== zeroAddress) {
    const tokenAbi = (await artifact("QuirkyStakeToken")).abi;
    await write(stakeToken, tokenAbi, "mint", [payer, 10n * stakeUnit]);
    await write(stakeToken, tokenAbi, "approve", [rounds, 10n * stakeUnit]);
  }
  await write(rounds, pots.abi, "fund", [10n * stakeUnit], stakeToken === zeroAddress ? 10n * stakeUnit : 0n);
  const block = await client.getBlock();
  const threshold = scenario === "marketcap" ? 10n ** 42n : 10n ** 36n;
  const settings = { openingStake: scenario === "unmatched" ? 0n : stakeUnit / 100n, stakeCap: stakeUnit / 10n, threshold, tradingSeconds: 30, windowSeconds: 4, endTime: block.timestamp + 86400n, metric: scenario === "marketcap" ? 1 : 0, reader, marketCapReader: scenario === "marketcap" ? capReader : zeroAddress };
  await write(rounds, pots.abi, "seedRound", [settings]);
  await mkdir(new URL("output/", root), { recursive: true });
  await writeFile(stateFile, JSON.stringify({ rpcUrl, payer, other, rounds, pool, reader, scenario, stakeToken }, null, 2));
  console.log(`NEXT_PUBLIC_THRESHOLD_ADDRESS=${rounds}\nOpen /rounds?brand=DEGEN&market=threshold`);
} else {
  const state = JSON.parse(await readFile(stateFile, "utf8"));
  if (command === "fund-player") {
    if (!isAddress(argument)) throw new Error("Pass Player address.");
    await rpc("anvil_setBalance", [argument, `0x${parseEther("10").toString(16)}`]);
    if (state.stakeToken !== zeroAddress) await write(state.stakeToken, (await artifact("QuirkyStakeToken")).abi, "mint", [argument, 10_000_000n]);
  } else if (command === "stake-other") {
    const side = argument === "no" ? 1 : 0;
    const amount = state.stakeToken === zeroAddress ? parseEther(extra || "0.01") : BigInt(Math.round(Number(extra || "0.01") * 1_000_000));
    if (state.stakeToken !== zeroAddress) {
      const tokenAbi = (await artifact("QuirkyStakeToken")).abi;
      await write(state.stakeToken, tokenAbi, "mint", [state.other, amount]);
      await write(state.stakeToken, tokenAbi, "approve", [state.rounds, amount], 0n, state.other);
    }
    await write(state.rounds, pots.abi, "stake", [1n, side, amount], state.stakeToken === zeroAddress ? amount : 0n, state.other);
  } else if (command === "settle" || command === "cutoff") {
    const id = BigInt(argument || "1");
    const r = await client.readContract({ address: state.rounds, abi: pots.abi, functionName: "round", args: [id] });
    if (r.result !== 0) throw new Error("Already settled.");
    if (command === "cutoff") { await timestamp(r.cutoff); await rpc("evm_mine"); }
    else {
      if (state.scenario !== "unmatched") {
        const tick = state.scenario === "tie" ? 0 : state.scenario === "no" ? -100 : 100;
        await write(state.pool, poolAbi, "write", [tick]);
        // Allow at least the lookback at the new tick before the exact endpoint.
        await timestamp(r.windowEnd);
        await write(state.rounds, pots.abi, "captureBoundary", [id]);
      } else { await timestamp(r.windowEnd); await rpc("evm_mine"); }
      const settled = await write(state.rounds, pots.abi, "settle", [id]);
      const result = await client.readContract({ address: state.rounds, abi: pots.abi, functionName: "round", args: [id] });
      console.log(`Round ${id}: ${["None", "Yes", "No", "Tie", "Unmatched", "Refunded"][result.result]} ${settled.transactionHash}`);
    }
  } else if (command === "refund") {
    // No boundary Reading is captured, so once the grace period passes anyone may refund the Round.
    const id = BigInt(argument || "1");
    const r = await client.readContract({ address: state.rounds, abi: pots.abi, functionName: "round", args: [id] });
    if (r.result !== 0) throw new Error("Already settled.");
    await timestamp(r.windowEnd + 61n);
    const refunded = await write(state.rounds, pots.abi, "settle", [id]);
    console.log(`Round ${id}: Refunded ${refunded.transactionHash}`);
  } else if (command === "inspect") {
    const player = argument || state.other;
    const id = BigInt(extra || "1");
    const value = await client.readContract({ address: state.rounds, abi: pots.abi, functionName: "claimable", args: [id, player] });
    console.log(`claimable=${value}`);
  } else throw new Error("Use setup [yes|no|tie|unmatched|marketcap|usdc], fund-player <address>, stake-other [yes|no] [amount], cutoff [id], settle [id], refund [id], inspect [player] [id].");
}

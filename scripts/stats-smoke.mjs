// Re-runnable browser smoke for "Payer Campaign stats" (#13). Localhost only.
//
//   node scripts/stats-smoke.mjs
//
// Needs anvil, forge, playwright-cli and installed workspace dependencies; ports 8545 and 3010 free.
// It trades two up/down Rounds and stakes one threshold Round with two Players, opens /rounds/stats,
// then settles each Round (up/down Round 2 as a Tie) and checks the page against the contract events
// and balances. It fails on any browser console error.
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { createConnection } from "node:net";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const rootPath = fileURLToPath(root);
const brandPath = fileURLToPath(new URL("packages/nextjs/public/brand.json", root));
const committedBrand = readFileSync(brandPath, "utf8");
const require = createRequire(new URL("packages/nextjs/package.json", root));
const { createPublicClient, createWalletClient, http, formatEther, parseAbi, parseEther } = require("viem");
const { foundry } = require("viem/chains");

const RPC = "http://127.0.0.1:8545";
const APP = "http://localhost:3010";
const SESSION = "-s=stats-smoke";
const COST = "0.5";
const client = createPublicClient({ chain: foundry, transport: http(RPC) });
const owned = [];
let passed = 0;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const pass = message => (passed++, console.log(`ok - ${message}`));
const portInUse = port =>
  new Promise(resolve => {
    const socket = createConnection({ port, host: "127.0.0.1" });
    socket.once("connect", () => (socket.destroy(), resolve(true)));
    socket.once("error", () => resolve(false));
  });
async function until(label, check, timeoutMs = 60_000) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    try {
      last = await check();
      if (last) return last;
    } catch (error) {
      last = error;
    }
    await sleep(500);
  }
  throw new Error(`Timed out waiting for ${label}. Last: ${last instanceof Error ? last.message : JSON.stringify(last)}`);
}
const run = (command, args) =>
  execFileSync(command, args, { cwd: rootPath, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
function start(command, args, env = {}, cwd = rootPath) {
  const child = spawn(command, args, { cwd, env: { ...process.env, ...env }, detached: true, stdio: "ignore" });
  owned.push(child);
  return child;
}
function pw(...args) {
  const out = execFileSync("playwright-cli", [SESSION, "--raw", ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  return out.split("\n").filter(line => !/^[╔║╚]/.test(line)).join("\n").trim();
}
const evaluate = expression => {
  const out = pw("run-code", `async page => { return await page.evaluate(${expression}); }`);
  return out ? JSON.parse(out) : undefined;
};
const testId = id => evaluate(`() => document.querySelector('[data-testid="${id}"]')?.innerText ?? null`);
const row = id => testId(id)?.replace(/\s+/g, " ").trim();
const eth = value => `${value > 0n ? "+" : ""}${formatEther(value)} ETH`;

if ((await portInUse(8545)) || (await portInUse(3010))) throw new Error("Ports 8545 and 3010 must be free.");

const roundsAbi = parseAbi([
  "function quote(uint256 roundId, uint8 side, uint256 shares) view returns (uint256)",
  "function quoteSell(uint256 roundId, uint8 side, uint256 shares) view returns (uint256)",
  "function buy(uint256 roundId, uint8 side, uint256 shares, uint256 maxCost) payable",
  "function sell(uint256 roundId, uint8 side, uint256 shares, uint256 minProceeds)",
  "function fundingBalance() view returns (uint256)",
  "function round(uint256 roundId) view returns ((address reader, address payer, uint256 cutoff, uint256 windowEnd, uint256 stakeCap, uint256 seededLiquidity, uint256 sharesPerSide, uint256 upSold, uint256 downSold, uint256 startBlock, uint256 endBlock, uint256 collateral, uint256 upLiability, uint256 downLiability, uint256 refundLiability, uint8 result, (uint256 blockNumber, uint256 timestamp, uint256 price) startReading, (uint256 blockNumber, uint256 timestamp, uint256 price) endReading))",
  "event Bought(uint256 indexed roundId, address indexed player, uint8 side, uint256 shares, uint256 cost)",
  "event Sold(uint256 indexed roundId, address indexed player, uint8 side, uint256 shares, uint256 proceeds)",
]);
const potsAbi = parseAbi([
  "function stake(uint256 roundId, uint8 side, uint256 amount) payable",
  "function claimable(uint256 roundId, address player) view returns (uint256)",
  "event Staked(uint256 indexed roundId, address indexed player, uint8 side, uint256 amount)",
  "event RoundSeeded(uint256 indexed roundId, address indexed payer, uint256 openingStake, uint256 cutoff, uint256 windowEnd)",
]);

try {
  start("anvil", ["--port", "8545", "--silent"]);
  await until("anvil", async () => (await client.getChainId()) === 31337, 20_000);
  run("forge", ["build", "--root", "packages/foundry"]);
  const addressOf = (output, name) => output.match(new RegExp(`${name}=(0x[0-9a-fA-F]{40})`))[1];
  const updown = addressOf(run("node", ["scripts/rounds-local.mjs", "setup"]), "NEXT_PUBLIC_ROUNDS_ADDRESS");
  const pots = addressOf(run("node", ["scripts/threshold-local.mjs", "setup", "yes"]), "NEXT_PUBLIC_THRESHOLD_ADDRESS");
  const [payer, p1, p2] = await client.request({ method: "eth_accounts" });
  const wallet = createWalletClient({ chain: foundry, transport: http(RPC) });
  const send = async (account, address, abi, functionName, args, value = 0n) => {
    const hash = await wallet.writeContract({ account, address, abi, functionName, args, value, gas: 3_000_000n });
    assert.equal((await client.waitForTransactionReceipt({ hash })).status, "success", functionName);
  };

  // Two Players trade up/down Round 1: p1 buys 3 Up and sells 1, p2 buys 2 Down.
  const buy = async (account, side, shares, roundId = 1n) => {
    const cost = await client.readContract({ address: updown, abi: roundsAbi, functionName: "quote", args: [roundId, side, shares] });
    await send(account, updown, roundsAbi, "buy", [roundId, side, shares, cost], cost);
  };
  await buy(p1, 0, parseEther("3"));
  await buy(p2, 1, parseEther("2"));
  const proceeds = await client.readContract({ address: updown, abi: roundsAbi, functionName: "quoteSell", args: [1n, 0, parseEther("1")] });
  await send(p1, updown, roundsAbi, "sell", [1n, 0, parseEther("1"), proceeds]);
  // Two Players stake threshold Round 1 next to the payer's Opening stakes.
  await send(p1, pots, potsAbi, "stake", [1n, 0, parseEther("0.05")], parseEther("0.05"));
  await send(p2, pots, potsAbi, "stake", [1n, 1, parseEther("0.02")], parseEther("0.02"));

  // Expected values come from the raw events, independent of the page's code.
  const logs = async (address, abi) => client.getContractEvents({ address, abi, fromBlock: 0n });
  const liquidity = (await client.readContract({ address: updown, abi: roundsAbi, functionName: "round", args: [1n] })).seededLiquidity;
  const upLogs = (await logs(updown, roundsAbi)).filter(l => l.args.roundId === 1n);
  // Volume is player buy cost only.
  const upVolume = upLogs.reduce((sum, l) => sum + (l.args.cost ?? 0n), 0n);
  const upPlayers = new Set(upLogs.map(l => l.args.player)).size;
  const potLogs = (await logs(pots, potsAbi)).filter(l => l.eventName === "Staked");
  const potVolume = potLogs.reduce((sum, l) => sum + l.args.amount, 0n);
  const opening = (await logs(pots, potsAbi)).find(l => l.eventName === "RoundSeeded").args.openingStake;

  const appEnv = {
    NEXT_TELEMETRY_DISABLED: "1",
    NEXT_PUBLIC_ROUNDS_ADDRESS: updown,
    NEXT_PUBLIC_THRESHOLD_ADDRESS: pots,
    NEXT_PUBLIC_DEGEN_CAMPAIGN_COST: COST,
  };
  const book = JSON.parse(committedBrand);
  for (const ticker of ["DEGEN", "BASE"]) {
    const entry = book[ticker];
    entry.chainId = 31337;
    entry.fromBlock = "0";
    entry.quoteTicker = "ETH";
    entry.address = ticker === "BASE" ? process.env.NEXT_PUBLIC_BASE_ROUNDS_ADDRESS || updown : updown;
    entry.thresholdAddress =
      ticker === "BASE" ? process.env.NEXT_PUBLIC_BASE_THRESHOLD_ADDRESS || pots : pots;
    const cost = appEnv[`NEXT_PUBLIC_${ticker}_CAMPAIGN_COST`] ?? process.env[`NEXT_PUBLIC_${ticker}_CAMPAIGN_COST`];
    if (cost) entry.campaignCost = cost;
    else delete entry.campaignCost;
  }
  writeFileSync(brandPath, `${JSON.stringify(book, null, 2)}\n`);
  start("yarn", ["next", "dev", "--webpack", "-p", "3010"], appEnv, `${rootPath}packages/nextjs`);
  await until("Next dev server", async () => (await fetch(`${APP}/rounds/stats`)).ok, 180_000);
  pw("open", `${APP}/rounds/stats?brand=DEGEN`);
  pw("console", "error"); // start from a clean console listing

  const upRow = await until("up/down row", () => row("stats-updown-1"));
  assert.equal(upRow, `Up/down #1 Open ${formatEther(upVolume)} ETH ${upPlayers} –`);
  pass(`open up/down Round matches events: ${upRow}`);
  const potRow = await until("threshold row", () => row("stats-threshold-1"));
  assert.equal(potRow, `Threshold #1 Open ${formatEther(potVolume)} ETH 2 –`);
  pass(`open threshold Round matches events: ${potRow}`);
  assert.equal(await testId("total-volume"), `${formatEther(upVolume + potVolume)} ETH`);
  assert.equal(await testId("campaign-cost"), `${COST} ETH`);
  assert.equal(await testId("total-pnl"), "0 ETH");
  pass("Campaign total shows volume and the configured Campaign cost; no Round ended yet");

  // Round 1 enters its Window so Round 2 trades: p1 buys 2 Up, p2 buys 1 Down.
  run("node", ["scripts/rounds-local.mjs", "cutoff", "1"]);
  await buy(p1, 0, parseEther("2"), 2n);
  await buy(p2, 1, parseEther("1"), 2n);
  const tieVolume = (await logs(updown, roundsAbi)).filter(l => l.args.roundId === 2n).reduce((sum, l) => sum + l.args.cost, 0n);

  // Settle up/down Round 1 (Up wins). The surplus released to funding, less the Round's liquidity, is the payer result.
  const fundingBefore = await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" });
  run("node", ["scripts/rounds-local.mjs", "settle", "1"]);
  const upPnl = (await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" })) - fundingBefore - liquidity;
  await until("up/down settled row", async () => (await row("stats-updown-1"))?.includes("Settled"));
  assert.equal(await row("stats-updown-1"), `Up/down #1 Settled ${formatEther(upVolume)} ETH ${upPlayers} ${eth(upPnl)}`);
  await until("total after up/down", async () => (await testId("total-pnl")) === eth(upPnl));
  pass(`up/down payer result ${eth(upPnl)} matches the contract's released surplus; total updated without reload`);

  // Settle threshold (Yes wins). Payer result = its claimable winnings minus both Opening stakes.
  run("node", ["scripts/threshold-local.mjs", "settle", "1"]);
  const potPnl = (await client.readContract({ address: pots, abi: potsAbi, functionName: "claimable", args: [1n, payer] })) - 2n * opening;
  await until("threshold settled row", async () => (await row("stats-threshold-1"))?.includes("Settled"));
  assert.equal(await row("stats-threshold-1"), `Threshold #1 Settled ${formatEther(potVolume)} ETH 2 ${eth(potPnl)}`);
  const total = upPnl + potPnl;
  await until("total after threshold", async () => (await testId("total-pnl")) === eth(total));
  assert.equal(await testId("total-spend"), `${formatEther(parseEther(COST) - total)} ETH`);
  pass(`threshold payer result ${eth(potPnl)} matches claimable; Campaign total ${eth(total)}, spend ${formatEther(parseEther(COST) - total)} ETH`);

  // Settle up/down Round 2 as a Tie. The surplus released to funding, less the Round's liquidity, is the payer result.
  const fundingBeforeTie = await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" });
  run("node", ["scripts/rounds-local.mjs", "settle", "2", "tie"]);
  const tieRound = await client.readContract({ address: updown, abi: roundsAbi, functionName: "round", args: [2n] });
  assert.equal(tieRound.result, 3, "Round 2 should settle as a Tie");
  const tiePnl = (await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" })) - fundingBeforeTie - tieRound.seededLiquidity;
  await until("up/down Tie row", async () => (await row("stats-updown-2"))?.includes("Settled"));
  assert.equal(await row("stats-updown-2"), `Up/down #2 Settled ${formatEther(tieVolume)} ETH 2 ${eth(tiePnl)}`);
  await until("total after Tie", async () => (await testId("total-pnl")) === eth(total + tiePnl));
  pass(`up/down Tie payer result ${eth(tiePnl)} matches the contract's released surplus`);

  for (const width of [375, 1280]) {
    pw("resize", String(width), "900");
    assert.equal(await evaluate(`() => document.documentElement.scrollWidth <= window.innerWidth`), true);
  }
  pass("no horizontal overflow at 375 and 1280px");
  const errors = pw("console", "error");
  assert.ok(!/\[error\]/i.test(errors), `browser console errors:\n${errors}`);
  pass("no browser console errors");
  console.log(`\n${passed} checks passed`);
} finally {
  try {
    writeFileSync(brandPath, committedBrand);
  } catch {
    // restore the committed brand book even when setup failed before a write
  }
  try {
    pw("close");
  } catch {}
  for (const child of owned) {
    try {
      process.kill(-child.pid, "SIGTERM");
    } catch {}
  }
}

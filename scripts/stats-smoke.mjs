// Re-runnable browser smoke for "Payer Campaign stats" (#13). Localhost only.
//
//   node scripts/stats-smoke.mjs
//
// Needs anvil, forge, playwright-cli and installed workspace dependencies; ports 8545 and 3010 free.
// It trades one up/down Round and stakes one threshold Round with two Players, opens /rounds/stats,
// then settles each Round and checks the page against the contract events and balances.
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { createConnection } from "node:net";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const rootPath = fileURLToPath(root);
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
  const fundingBefore = await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" });

  // Two Players trade up/down Round 1: p1 buys 3 Up and sells 1, p2 buys 2 Down.
  const buy = async (account, side, shares) => {
    const cost = await client.readContract({ address: updown, abi: roundsAbi, functionName: "quote", args: [1n, side, shares] });
    await send(account, updown, roundsAbi, "buy", [1n, side, shares, cost], cost);
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
  const seed = (await client.getContractEvents({ address: updown, abi: parseAbi(["event RoundSeeded(uint256 indexed roundId, uint256 seed, uint256 cutoff, uint256 windowEnd, uint256 stakeCap)"]), fromBlock: 0n }))[0].args.seed;
  const upLogs = (await logs(updown, roundsAbi)).filter(l => l.args.roundId === 1n);
  const upVolume = upLogs.reduce((sum, l) => sum + (l.args.cost ?? l.args.proceeds), 0n);
  const upPlayers = new Set(upLogs.map(l => l.args.player)).size;
  const potLogs = (await logs(pots, potsAbi)).filter(l => l.eventName === "Staked");
  const potVolume = potLogs.reduce((sum, l) => sum + l.args.amount, 0n);
  const opening = (await logs(pots, potsAbi)).find(l => l.eventName === "RoundSeeded").args.openingStake;

  start("yarn", ["next", "dev", "--webpack", "-p", "3010"], {
    NEXT_TELEMETRY_DISABLED: "1",
    NEXT_PUBLIC_ROUNDS_ADDRESS: updown,
    NEXT_PUBLIC_THRESHOLD_ADDRESS: pots,
    NEXT_PUBLIC_DEGEN_CAMPAIGN_COST: COST,
  }, `${rootPath}packages/nextjs`);
  await until("Next dev server", async () => (await fetch(`${APP}/rounds/stats`)).ok, 180_000);
  pw("open", `${APP}/rounds/stats?brand=DEGEN`);

  const upRow = await until("up/down row", () => row("stats-updown-1"));
  assert.equal(upRow, `Up/down #1 Open ${formatEther(upVolume)} ETH ${upPlayers} Pending`);
  pass(`open up/down Round matches events: ${upRow}`);
  const potRow = await until("threshold row", () => row("stats-threshold-1"));
  assert.equal(potRow, `Threshold #1 Open ${formatEther(potVolume)} ETH 2 Pending`);
  pass(`open threshold Round matches events: ${potRow}`);
  assert.equal(await testId("total-volume"), `${formatEther(upVolume + potVolume)} ETH`);
  assert.equal(await testId("campaign-cost"), `${COST} ETH`);
  assert.equal(await testId("total-pnl"), "0 ETH");
  pass("Campaign total shows volume and the configured Campaign cost; no Round ended yet");

  // Settle up/down (Up wins). Payer result = funding after settlement minus funding before seeding.
  run("node", ["scripts/rounds-local.mjs", "settle", "1"]);
  const upPnl = (await client.readContract({ address: updown, abi: roundsAbi, functionName: "fundingBalance" })) - fundingBefore - seed;
  await until("up/down settled row", async () => (await row("stats-updown-1"))?.includes("Settled"));
  assert.equal(await row("stats-updown-1"), `Up/down #1 Settled ${formatEther(upVolume)} ETH ${upPlayers} ${eth(upPnl)}`);
  await until("total after up/down", async () => (await testId("total-pnl")) === eth(upPnl));
  pass(`up/down payer result ${eth(upPnl)} matches the contract's released funding; total updated without reload`);

  // Settle threshold (Yes wins). Payer result = its claimable winnings minus both Opening stakes.
  run("node", ["scripts/threshold-local.mjs", "settle", "1"]);
  const potPnl = (await client.readContract({ address: pots, abi: potsAbi, functionName: "claimable", args: [1n, payer] })) - 2n * opening;
  await until("threshold settled row", async () => (await row("stats-threshold-1"))?.includes("Settled"));
  assert.equal(await row("stats-threshold-1"), `Threshold #1 Settled ${formatEther(potVolume)} ETH 2 ${eth(potPnl)}`);
  const total = upPnl + potPnl;
  await until("total after threshold", async () => (await testId("total-pnl")) === eth(total));
  assert.equal(await testId("total-spend"), `${formatEther(parseEther(COST) - total)} ETH`);
  pass(`threshold payer result ${eth(potPnl)} matches claimable; Campaign total ${eth(total)}, spend ${formatEther(parseEther(COST) - total)} ETH`);

  for (const width of [375, 1280]) {
    pw("resize", String(width), "900");
    assert.equal(await evaluate(`() => document.documentElement.scrollWidth <= window.innerWidth`), true);
  }
  pass("no horizontal overflow at 375 and 1280px");
  console.log(`\n${passed} checks passed`);
} finally {
  try {
    pw("close");
  } catch {}
  for (const child of owned) {
    try {
      process.kill(-child.pid, "SIGTERM");
    } catch {}
  }
}

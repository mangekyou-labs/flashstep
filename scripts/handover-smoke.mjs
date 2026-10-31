// Static-export smoke for the handover build (#14). Localhost only.
//
//   yarn workspace @se-2/nextjs export
//   node scripts/handover-smoke.mjs
//
// Export is a separate command. This script fails if packages/nextjs/out/rounds/index.html
// is missing, or if TCP 8545 or 3020 is already open. It starts its own anvil and static
// server and stops them on exit. It does not modify packages/nextjs/public/brand.json.
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createConnection } from "node:net";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const rootPath = fileURLToPath(root);
const outDir = fileURLToPath(new URL("packages/nextjs/out/", root));
const indexHtml = fileURLToPath(new URL("packages/nextjs/out/rounds/index.html", root));
const publicBrand = fileURLToPath(new URL("packages/nextjs/public/brand.json", root));
const servedBrand = fileURLToPath(new URL("packages/nextjs/out/brand.json", root));
const artifactDir = fileURLToPath(new URL("output/playwright/", root));
const SESSION = "-s=handover-14";
const APP = "http://127.0.0.1:3020";
const owned = [];

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
async function portInUse(port) {
  return new Promise(resolve => {
    const socket = createConnection({ port, host: "127.0.0.1" });
    socket.once("connect", () => (socket.destroy(), resolve(true)));
    socket.once("error", () => resolve(false));
  });
}
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
function run(command, args) {
  return execFileSync(command, args, { cwd: rootPath, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] });
}
function start(command, args, env = {}, cwd = rootPath) {
  const child = spawn(command, args, { cwd, env: { ...process.env, ...env }, detached: true, stdio: "ignore" });
  owned.push(child);
  return child;
}
async function stop(child) {
  if (child.exitCode !== null) return;
  try {
    process.kill(-child.pid, "SIGTERM");
  } catch {
    return;
  }
  await until("process stop", () => child.exitCode !== null || child.signalCode !== null, 15_000).catch(() => {});
}
function pw(...args) {
  mkdirSync(artifactDir, { recursive: true });
  const out = execFileSync("playwright-cli", [SESSION, "--raw", ...args], {
    cwd: artifactDir,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  return out
    .split("\n")
    .filter(line => !/^[╔║╚]/.test(line))
    .join("\n")
    .trim();
}
function inPage(body) {
  const out = pw("run-code", `async page => { ${body} }`);
  return out ? JSON.parse(out) : undefined;
}
const surface = () =>
  inPage(`return await page.evaluate(() => {
    const text = selector => document.querySelector(selector)?.innerText ?? "";
    return {
      brand: text(".round-brand"),
      countdown: text(".round-countdown"),
      history: text(".round-history"),
      alert: text('[role="alert"]'),
      status: text('[role="status"]'),
    };
  });`);

if (!existsSync(indexHtml)) {
  throw new Error("packages/nextjs/out/rounds/index.html is missing. Run the export before this smoke.");
}
if ((await portInUse(8545)) || (await portInUse(3020))) {
  throw new Error("Ports 8545 and 3020 must be free. Refusing to reuse a stranger chain or static server.");
}

try {
  start("anvil", ["--host", "127.0.0.1", "--port", "8545", "--silent"]);
  await until(
    "anvil",
    async () => {
      const response = await fetch("http://127.0.0.1:8545", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }),
      });
      const body = await response.json();
      return body.result === "0x7a69";
    },
    20_000,
  );
  run("forge", ["build", "--root", "packages/foundry"]);

  const setupOut = run("node", ["scripts/rounds-local.mjs", "setup"]);
  const updown = setupOut.match(/NEXT_PUBLIC_ROUNDS_ADDRESS=(0x[0-9a-fA-F]{40})/)?.[1];
  if (!updown) throw new Error(`Up/down setup did not print an address:\n${setupOut}`);
  const settleOut = run("node", ["scripts/rounds-local.mjs", "settle", "1", "tie"]);
  const roundId = settleOut.match(/Round (\d+) settled Tie/)?.[1];
  if (!roundId) throw new Error(`Up/down round did not settle as Tie:\n${settleOut}`);

  const potsSetup = run("node", ["scripts/threshold-local.mjs", "setup", "unmatched"]);
  const pots = potsSetup.match(/NEXT_PUBLIC_THRESHOLD_ADDRESS=(0x[0-9a-fA-F]{40})/)?.[1];
  if (!pots) throw new Error(`Threshold setup did not print an address:\n${potsSetup}`);
  const potsSettle = run("node", ["scripts/threshold-local.mjs", "settle", "1"]);
  if (!/Round \d+: (?:Unmatched|Tie) /.test(potsSettle)) {
    throw new Error(`Threshold round did not settle as Unmatched or Tie:\n${potsSettle}`);
  }
  console.log(`fixtures: updown ${updown} round ${roundId}, pots ${pots}`);

  const book = JSON.parse(readFileSync(publicBrand, "utf8"));
  book.HANDOVER = {
    name: "Handover",
    ticker: "HANDOVER",
    logo: "/rounds/degen.svg",
    accent: "#6d28d9",
    up: "#167349",
    down: "#b6333b",
    address: updown,
    thresholdAddress: pots,
    chainId: 31337,
    quoteTicker: "ETH",
    explorerUrl: "",
    fromBlock: "0",
  };
  writeFileSync(servedBrand, `${JSON.stringify(book, null, 2)}\n`);

  start("python3", ["-m", "http.server", "3020", "--bind", "127.0.0.1", "--directory", outDir]);
  await until("static server", async () => (await fetch(`${APP}/rounds/`)).ok, 20_000);

  pw("open", `${APP}/rounds/?brand=HANDOVER`);
  const updownView = await until(
    "Handover header and Tie",
    async () => {
      const seen = surface();
      const rendered = `${seen.countdown}\n${seen.history}`;
      if (seen.brand.includes("Handover") && /\bTie\b/.test(rendered)) return seen;
      return null;
    },
    90_000,
  );
  assert.match(updownView.brand, /Handover/);
  assert.match(`${updownView.countdown}\n${updownView.history}`, /\bTie\b/);
  console.log(`ok - up/down shows Handover and Tie (${updownView.countdown} / ${updownView.history})`);

  pw("goto", `${APP}/rounds/?brand=HANDOVER&market=threshold`);
  const thresholdView = await until(
    "threshold refund result",
    async () => {
      const seen = surface();
      const rendered = `${seen.countdown}\n${seen.history}`;
      if (seen.brand.includes("Handover") && /Unmatched · refund|Tie · refund/.test(rendered)) return seen;
      return null;
    },
    90_000,
  );
  assert.match(thresholdView.brand, /Handover/);
  assert.match(`${thresholdView.countdown}\n${thresholdView.history}`, /Unmatched · refund|Tie · refund/);
  console.log(`ok - threshold shows Handover and a refund result (${thresholdView.countdown} / ${thresholdView.history})`);
} finally {
  try {
    pw("close");
  } catch {
    // browser already closed
  }
  for (const child of owned.reverse()) await stop(child);
}

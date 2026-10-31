// Re-runnable browser smoke for "Proof and sharing on the page" (#10). Localhost only.
//
//   node scripts/proof-smoke.mjs
//
// Needs anvil, forge, playwright-cli and installed workspace dependencies. It starts its own anvil
// on 8545 and its own Next dev server on 3010, settles one up/down Round, one threshold Round and
// refunds a second threshold Round, then drives the page with playwright-cli. Everything it starts
// is stopped on exit. Run it twice-in-one: first with an explorer configured, then without.
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
const { createPublicClient, http, formatEther, parseAbi, encodeFunctionData, parseEther } = require("viem");
const { foundry } = require("viem/chains");

const RPC = "http://127.0.0.1:8545";
const APP = "http://localhost:3010";
const HOST_PAGE = "http://127.0.0.1:3011";
const EXPLORER = "https://sepolia.basescan.org";
const SESSION = "-s=proof-smoke";
const client = createPublicClient({ chain: foundry, transport: http(RPC) });
const owned = []; // process groups started here, stopped in the finally block
let passed = 0;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
function pass(message) {
  passed++;
  console.log(`ok - ${message}`);
}
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
function run(command, args, options = {}) {
  return execFileSync(command, args, { cwd: rootPath, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"], ...options });
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

// playwright-cli prints an update banner on stdout; drop its box lines and keep the result.
function pw(...args) {
  const out = execFileSync("playwright-cli", [SESSION, "--raw", ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  return out.split("\n").filter(line => !/^[╔║╚]/.test(line)).join("\n").trim();
}
/** Run `body` as an async function of `page` and return its JSON-serializable result. */
function inPage(body) {
  const out = pw("run-code", `async page => { ${body} }`);
  return out ? JSON.parse(out) : undefined;
}
const evaluate = expression => inPage(`return await page.evaluate(${expression});`);

async function goto(path, base = APP) {
  pw("goto", `${base}${path}`);
}
const tableRows = () =>
  evaluate(`() => [...document.querySelectorAll(".round-history tbody tr")].map(tr => ({
    text: tr.innerText.replace(/\\s+/g, " ").trim(),
    links: [...tr.querySelectorAll("a")].map(a => a.href),
    code: [...tr.querySelectorAll("code")].map(c => c.innerText),
  }))`);
const bodyText = () => evaluate(`() => document.body.innerText`);
const testId = id => evaluate(`() => document.querySelector('[data-testid="${id}"]')?.innerText ?? null`);

function writeBrand(env) {
  const book = JSON.parse(committedBrand);
  for (const ticker of ["DEGEN", "BASE"]) {
    const entry = book[ticker];
    entry.chainId = 31337;
    entry.fromBlock = "0";
    entry.quoteTicker = "ETH";
    if (ticker === "DEGEN") {
      entry.address = env.NEXT_PUBLIC_ROUNDS_ADDRESS;
      entry.thresholdAddress = env.NEXT_PUBLIC_THRESHOLD_ADDRESS;
    } else {
      entry.address = env.NEXT_PUBLIC_BASE_ROUNDS_ADDRESS || env.NEXT_PUBLIC_ROUNDS_ADDRESS;
      entry.thresholdAddress = env.NEXT_PUBLIC_BASE_THRESHOLD_ADDRESS || env.NEXT_PUBLIC_THRESHOLD_ADDRESS;
    }
    const specific = env[`NEXT_PUBLIC_${ticker}_EXPLORER_URL`];
    if (specific !== undefined) entry.explorerUrl = specific;
    else if (env.NEXT_PUBLIC_EXPLORER_URL !== undefined) entry.explorerUrl = env.NEXT_PUBLIC_EXPLORER_URL;
    else entry.explorerUrl = EXPLORER;
    const cost = env[`NEXT_PUBLIC_${ticker}_CAMPAIGN_COST`];
    if (cost) entry.campaignCost = cost;
    else delete entry.campaignCost;
  }
  writeFileSync(brandPath, `${JSON.stringify(book, null, 2)}\n`);
}

async function startApp(env) {
  writeBrand(env);
  const app = start("yarn", ["next", "dev", "--webpack", "-p", "3010"], { NEXT_TELEMETRY_DISABLED: "1", ...env }, `${rootPath}packages/nextjs`);
  await until("Next dev server", async () => (await fetch(`${APP}/rounds`)).ok, 180_000);
  return app;
}

if ((await portInUse(8545)) || (await portInUse(3010)) || (await portInUse(3011))) {
  throw new Error("Ports 8545, 3010 and 3011 must be free; stop the other anvil or Next server first.");
}

try {
  // Fixtures: one settled up/down Round, one settled threshold Round, one refunded threshold Round.
  start("anvil", ["--port", "8545", "--silent"]);
  await until("anvil", async () => (await client.getChainId()) === 31337, 20_000);
  run("forge", ["build", "--root", "packages/foundry"]);
  const addressOf = (output, name) => output.match(new RegExp(`${name}=(0x[0-9a-fA-F]{40})`))[1];
  const hashOf = output => output.match(/(0x[0-9a-fA-F]{64})/)[1];
  const roundsAddress = addressOf(run("node", ["scripts/rounds-local.mjs", "setup"]), "NEXT_PUBLIC_ROUNDS_ADDRESS");
  run("node", ["scripts/rounds-local.mjs", "cutoff", "1"]);
  const upDownSettleTx = hashOf(run("node", ["scripts/rounds-local.mjs", "settle", "1"]));
  const settledPots = addressOf(run("node", ["scripts/threshold-local.mjs", "setup", "yes"]), "NEXT_PUBLIC_THRESHOLD_ADDRESS");
  run("node", ["scripts/threshold-local.mjs", "cutoff", "1"]);
  const thresholdSettleTx = hashOf(run("node", ["scripts/threshold-local.mjs", "settle", "1"]));
  const refundedPots = addressOf(run("node", ["scripts/threshold-local.mjs", "setup", "yes"]), "NEXT_PUBLIC_THRESHOLD_ADDRESS");
  run("node", ["scripts/threshold-local.mjs", "cutoff", "1"]);
  const thresholdRefundTx = hashOf(run("node", ["scripts/threshold-local.mjs", "refund", "1"]));
  console.log(`fixtures: updown ${roundsAddress}, DEGEN threshold ${settledPots}, BASE threshold ${refundedPots}`);

  const fixtureEnv = {
    NEXT_PUBLIC_ROUNDS_ADDRESS: roundsAddress,
    NEXT_PUBLIC_THRESHOLD_ADDRESS: settledPots,
    NEXT_PUBLIC_BASE_THRESHOLD_ADDRESS: refundedPots,
  };

  // Host page that embeds the Rounds page, as a payer's site would.
  // A separate process: this script blocks on execFileSync, so an in-process server could not answer.
  const hostSource = `require("node:http").createServer((request, response) => {
    const src = new URL(request.url, "${HOST_PAGE}").searchParams.get("src") ?? "";
    response.writeHead(200, { "content-type": "text/html" });
    response.end('<!doctype html><title>Payer site</title><iframe src="' + src + '" width="900" height="1400" style="border:0"></iframe>');
  }).listen(3011, "127.0.0.1");`;
  start("node", ["-e", hostSource]);
  await until("host page", async () => (await fetch(HOST_PAGE)).ok, 10_000);

  pw("open", "about:blank");
  inPage(`await page.context().grantPermissions(["clipboard-read", "clipboard-write"], { origin: "${APP}" });`);

  // ---- Phase A: explorer configured --------------------------------------------------------
  let app = await startApp({ ...fixtureEnv, NEXT_PUBLIC_EXPLORER_URL: EXPLORER, ROUNDS_FRAME_ANCESTORS: "" });

  const headers = (await fetch(`${APP}/rounds`)).headers;
  assert.equal(headers.get("content-security-policy"), "frame-ancestors *");
  assert.equal(headers.get("x-frame-options"), null);
  pass("page is frameable by any site by default (CSP frame-ancestors *, no X-Frame-Options)");

  // Recent Rounds: result, both Readings and the settle-tx link.
  await goto("/rounds?brand=DEGEN");
  const upDownRow = await until("settled up/down row", async () =>
    (await tableRows()).find(row => row.links.includes(`${EXPLORER}/tx/${upDownSettleTx}`)),
  );
  assert.match(upDownRow.text, /\bUp\b/);
  assert.match(upDownRow.text, /\d[\d.,]* → \d[\d.,]*/);
  pass(`up/down row shows result and both Readings (${upDownRow.text})`);
  pass("up/down row links to its settle tx on the explorer");

  // Pool balance equals the contract, and refreshes after funding.
  const poolViews = parseAbi([
    "function fundingBalance() view returns (uint256)",
    "function reservedBalance() view returns (uint256)",
  ]);
  const read = functionName => client.readContract({ address: roundsAddress, abi: poolViews, functionName });
  const held = () => client.getBalance({ address: roundsAddress });
  assert.equal(await held(), (await read("fundingBalance")) + (await read("reservedBalance")));
  const poolText = () => testId("pool-balance");
  await until("pool balance", async () => (await poolText())?.startsWith(`${formatEther(await held())} ETH`));
  pass(`pool balance shows the contract balance (${formatEther(await held())} ETH)`);
  const [payer] = await client.request({ method: "eth_accounts" });
  const fundTx = await client.request({
    method: "eth_sendTransaction",
    params: [
      {
        from: payer,
        to: roundsAddress,
        value: `0x${parseEther("1").toString(16)}`,
        data: encodeFunctionData({ abi: parseAbi(["function fund(uint256 amount) payable"]), functionName: "fund", args: [parseEther("1")] }),
        gas: "0x100000",
      },
    ],
  });
  const fundReceipt = await client.waitForTransactionReceipt({ hash: fundTx });
  assert.equal(fundReceipt.status, "success", "fund() reverted");
  const afterFunding = await held();
  console.log(`page shows: ${await poolText()}, expecting ${formatEther(afterFunding)} ETH`);
  await until("pool balance to refresh after funding", async () => (await poolText())?.startsWith(`${formatEther(afterFunding)} ETH`));
  assert.equal(afterFunding, (await read("fundingBalance")) + (await read("reservedBalance")));
  pass(`pool balance refreshed to ${formatEther(afterFunding)} ETH after funding 1 ETH, matching the contract views`);

  // Share links open the right Round.
  await goto("/rounds?brand=DEGEN&round=1");
  const shareUrl = await until("share url", () => testId("share-url"));
  assert.equal(shareUrl, `${APP}/rounds?brand=DEGEN&round=1`);
  const shareHrefs = await evaluate(`() => [...document.querySelectorAll(".round-share-links a")].map(a => a.href)`);
  const [xLink, telegramLink] = shareHrefs.map(href => new URL(href));
  assert.equal(xLink.hostname, "x.com");
  assert.equal(xLink.searchParams.get("url"), shareUrl);
  assert.equal(telegramLink.hostname, "t.me");
  assert.equal(telegramLink.searchParams.get("url"), shareUrl);
  await goto(new URL(xLink.searchParams.get("url")).pathname + new URL(shareUrl).search);
  await until("shared Round #1 to load", async () => /Round #1\b/.test(await bodyText()));
  pass("X and Telegram links carry the Round URL, and opening it loads that Round");

  // Copy button.
  await evaluate(`() => document.querySelector(".round-share-links button").click()`);
  await until("copy confirmation", async () => /Link copied/.test(await bodyText()));
  assert.equal(await evaluate(`() => navigator.clipboard.readText()`), shareUrl);
  pass("copy link puts the Round URL on the clipboard");

  // Iframe embedding.
  await goto(`/?src=${encodeURIComponent(`${APP}/rounds?brand=BASE&round=1`)}`, HOST_PAGE);
  const framed = await until("framed page", async () => {
    const text = await inPage(`const frame = page.frames().find(f => f.url().startsWith("${APP}")); return frame ? await frame.evaluate(() => document.body.innerText) : null;`);
    return text?.includes("Pool balance") ? text : null;
  });
  assert.match(framed, /Round #1\b/);
  assert.match(framed, /Share Round #1/);
  pass("page renders inside an iframe on another origin with its share links and pool balance");

  // A failing log lookup is visible and retryable, not a permanent "Looking up…".
  inPage(`await page.route(url => url.port === "8545", route => {
    const body = route.request().postData() ?? "";
    if (!body.includes("eth_getLogs")) return route.continue();
    return route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ jsonrpc: "2.0", id: JSON.parse(body).id, error: { code: -32000, message: "block range too large" } }) });
  });`);
  await goto("/rounds?brand=DEGEN");
  await until("lookup failure", async () => /Lookup failed/.test(await bodyText()));
  inPage(`await page.unrouteAll({ behavior: "ignoreErrors" });`);
  await evaluate(`() => [...document.querySelectorAll(".round-history button")].find(b => b.innerText === "Retry").click()`);
  await until("retry to find the settle tx", async () =>
    (await tableRows()).find(row => row.links.includes(`${EXPLORER}/tx/${upDownSettleTx}`)),
  );
  pass("a failed log lookup shows 'Lookup failed' and Retry recovers the settle link");

  // Threshold market: settled and refunded Rounds.
  await goto("/rounds?brand=DEGEN&market=threshold");
  const thresholdRow = await until("settled threshold row", async () =>
    (await tableRows()).find(row => row.links.includes(`${EXPLORER}/tx/${thresholdSettleTx}`)),
  );
  assert.match(thresholdRow.text, /\bYes\b/);
  assert.match(thresholdRow.text, /\d[\d.,]* ETH \d[\d.,]* ETH/); // threshold, then End Reading
  pass(`threshold row shows result, threshold and End Reading with a settle link (${thresholdRow.text})`);
  const heldPots = await client.getBalance({ address: settledPots });
  await until("threshold pool", async () => (await poolText())?.startsWith(`${formatEther(heldPots)} ETH`));
  pass(`threshold pool balance matches the contract (${formatEther(heldPots)} ETH)`);

  await goto("/rounds?brand=BASE&market=threshold");
  const refundRow = await until("refunded threshold row", async () =>
    (await tableRows()).find(row => row.links.includes(`${EXPLORER}/tx/${thresholdRefundTx}`)),
  );
  assert.match(refundRow.links.length ? refundRow.text : "", /Refund tx 0x/);
  pass(`refunded Round links "Refund tx" (${refundRow.text})`);

  // Layout at the three target widths, and no console errors.
  for (const width of [375, 768, 1280]) {
    pw("resize", String(width), "900");
    await goto("/rounds?brand=DEGEN");
    await until("table", async () => (await tableRows()).length > 0);
    const { scrollWidth, innerWidth } = await evaluate(`() => ({ scrollWidth: document.documentElement.scrollWidth, innerWidth: window.innerWidth })`);
    assert.ok(scrollWidth <= innerWidth, `horizontal overflow at ${width}px: ${scrollWidth} > ${innerWidth}`);
    pass(`no horizontal overflow at ${width}px`);
  }
  const consoleErrors = pw("console", "error");
  assert.ok(!/\[ERROR\]/i.test(consoleErrors), `console errors:\n${consoleErrors}`);
  pass("no console errors");

  // ---- Phase B: no explorer, embedding restricted ----------------------------------------------
  await stop(app);
  app = await startApp({ ...fixtureEnv, NEXT_PUBLIC_EXPLORER_URL: "", ROUNDS_FRAME_ANCESTORS: "https://payer.example" });
  assert.equal((await fetch(`${APP}/rounds`)).headers.get("content-security-policy"), "frame-ancestors https://payer.example");
  pass("ROUNDS_FRAME_ANCESTORS restricts the CSP to the configured origin");

  pw("resize", "1280", "900");
  await goto("/rounds?brand=DEGEN");
  const plainRow = await until("settle tx without explorer", async () =>
    (await tableRows()).find(row => row.code.some(text => text.startsWith(upDownSettleTx.slice(0, 8)))),
  );
  assert.deepEqual(plainRow.links, []);
  assert.match((await testId("no-explorer-note")) ?? "", /No block explorer is configured/);
  pass("without an explorer the hash is plain text and a visible note says why");

  await goto(`/?src=${encodeURIComponent(`${APP}/rounds?brand=BASE&round=1`)}`, HOST_PAGE);
  await sleep(4_000);
  const blocked = await inPage(`const frame = page.frames().find(f => f.url().startsWith("${APP}")); return frame ? await frame.evaluate(() => document.body.innerText) : null;`);
  assert.ok(!blocked?.includes("Pool balance"), "the restricted CSP should block a foreign embedder");
  pass("a site outside ROUNDS_FRAME_ANCESTORS cannot embed the page");

  console.log(`\n${passed} checks passed`);
} finally {
  try {
    writeFileSync(brandPath, committedBrand);
  } catch {
    // restore the committed brand book even when setup failed before a write
  }
  try {
    pw("close");
  } catch {
    // browser already closed
  }
  for (const child of owned.reverse()) {
    if (child.close) child.close();
    else await stop(child);
  }
}
process.exit(0);

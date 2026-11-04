import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { createServer } from "node:http";
import { ethers } from "ethers";

// Regression for native 200ms blocks, realistic read latency and restart discovery.
// evm_mine permits repeated whole-second timestamps on the local Anvil fixture.
const latency = Number(process.env.SMOKE_RPC_LATENCY_MS ?? 60);
if (!Number.isSafeInteger(latency) || latency < 0 || latency > 2000)
  throw new Error("Invalid SMOKE_RPC_LATENCY_MS");
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const port = 19000 + Math.floor(Math.random() * 1000);
const url = `http://127.0.0.1:${port}`;
const anvil = spawn("anvil", ["--port", String(port), "--silent"], {
  stdio: "ignore",
});
const provider = new ethers.providers.JsonRpcProvider(url);
provider.pollingInterval = 20;
const children = [];
const overlap = process.argv.includes("--overlap");
const late = process.argv.includes("--late");
const nativeTimes = new Map();
let latestNativeMs = 0;
let firstBoundaryMs = 0;
let delayed = false;
const proxy = createServer(async (req, res) => {
  await sleep(latency); // Network round trips must not stall deadline-sensitive captures.
  let body = "";
  for await (const chunk of req) body += chunk;
  try {
    const request = JSON.parse(body);
    if (
      late &&
      !delayed &&
      (Array.isArray(request) ? request : [request]).some(
        (r) => r.method === "eth_sendRawTransaction"
      )
    ) {
      delayed = true;
      // Simulate a real inclusion failure, not a fabricated receipt: hold the
      // signed capture until its valid timestamp second has already passed.
      while (latestNativeMs < firstBoundaryMs + 1000) await sleep(20);
    }
    const reply = await fetch(url, {
      method: "POST",
      body,
      headers: { "content-type": "application/json" },
    });
    res.writeHead(reply.status, { "content-type": "application/json" });
    const response = await reply.json();
    const requests = Array.isArray(request) ? request : [request];
    for (const reply of Array.isArray(response) ? response : [response]) {
      const call = requests.find((r) => r.id === reply.id);
      if (call?.method === "eth_getBlockByNumber" && reply.result) {
        const ms = nativeTimes.get(reply.result.number);
        if (ms != null) reply.result.timestampMs = ethers.utils.hexValue(ms);
      }
    }
    // JSON-RPC batches may return out of request order. Exercise id matching.
    res.end(
      JSON.stringify(Array.isArray(response) ? response.reverse() : response)
    );
  } catch {
    res.writeHead(502);
    res.end();
  }
});
const artifact = async (name) =>
  JSON.parse(
    await readFile(
      new URL(
        `../out/${
          name.startsWith("Mock") ? "MockBasePool" : name
        }.sol/${name}.json`,
        import.meta.url
      )
    )
  );
const deadline = async (fn, message) => {
  for (let attempt = 0; attempt < 200; attempt++) {
    if (await fn()) return;
    await sleep(25);
  }
  throw new Error(message);
};

try {
  await deadline(async () => {
    try {
      await provider.send("eth_chainId", []);
      return true;
    } catch {
      return false;
    }
  }, "Anvil did not start");
  await new Promise((resolve) => proxy.listen(0, "127.0.0.1", resolve));
  const botUrl = `http://127.0.0.1:${proxy.address().port}`;
  const owner = provider.getSigner(0);
  const payer = await owner.getAddress();
  const deploy = async (name, args) => {
    const a = await artifact(name);
    const contract = await new ethers.ContractFactory(
      a.abi,
      a.bytecode.object,
      owner
    ).deploy(...args);
    await contract.deployed();
    return contract;
  };
  const base = await deploy("MockReadingToken", [
    18,
    ethers.constants.WeiPerEther,
  ]);
  const quote = await deploy("MockReadingToken", [
    18,
    ethers.constants.WeiPerEther,
  ]);
  const pool = await deploy("MockBasePool", [base.address, quote.address]);
  await (await pool.write(0)).wait();
  const reader = await deploy("BasePoolReader", [
    pool.address,
    base.address,
    4,
  ]);
  const up = await deploy("UpDownRounds", [
    payer,
    reader.address,
    ethers.constants.AddressZero,
    ethers.utils.parseEther("0.01"),
  ]);
  const pot = await deploy("ThresholdPots", [
    payer,
    reader.address,
    ethers.constants.AddressZero,
  ]);
  for (const c of [up, pot])
    await (
      await c.fund(ethers.utils.parseEther("10"), {
        value: ethers.utils.parseEther("10"),
      })
    ).wait();
  const t = (await provider.getBlock("latest")).timestamp + 10;
  await provider.send("evm_setAutomine", [false]);
  const nonce = await owner.getTransactionCount();
  await up.seedRound(
    ethers.utils.parseEther("1"),
    ethers.utils.parseEther("1"),
    overlap ? 6 : 10,
    overlap ? 6 : 4,
    { gasLimit: 1500000, nonce }
  );
  await pot.seedRound(
    [
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("1"),
      ethers.BigNumber.from(10).pow(36).sub(1),
      overlap ? 6 : 10,
      overlap ? 6 : 4,
      t + (overlap ? 18 : 10),
      0,
      reader.address,
      ethers.constants.AddressZero,
    ],
    { gasLimit: 1500000, nonce: nonce + 1 }
  );
  await provider.send("evm_setNextBlockTimestamp", [t]);
  await provider.send("evm_mine", []);
  if (!overlap) {
    await up.stopCampaign({ gasLimit: 1500000, nonce: nonce + 2 });
    await pot.stopCampaign({ gasLimit: 1500000, nonce: nonce + 3 });
  }
  // Startup must infer native cadence from actual adjacent block timestamps.
  await provider.send("evm_mine", [t]);
  await provider.send("evm_mine", [t]);
  latestNativeMs = t * 1000;
  firstBoundaryMs = (t + 10) * 1000;
  nativeTimes.set(
    (await provider.send("eth_getBlockByNumber", ["latest", false])).number,
    latestNativeMs
  );
  const logs = [];
  const startBot = (
    upAddress = up.address,
    potAddress = pot.address,
    extraEnv = {}
  ) => {
    const bot = spawn(
      process.execPath,
      [fileURLToPath(new URL("settleBot.js", import.meta.url))],
      {
        env: {
          ...process.env,
          SETTLE_RPC_URL: botUrl,
          SETTLE_PRIVATE_KEY: ethers.Wallet.fromMnemonic(
            "test test test test test test test test test test test junk",
            "m/44'/60'/0'/0/1"
          ).privateKey,
          SETTLE_UPDOWN_ADDRESS: upAddress,
          SETTLE_THRESHOLD_ADDRESS: potAddress,
          SETTLE_FROM_BLOCK: "0",
          ...extraEnv,
        },
        stdio: ["ignore", "pipe", "pipe"],
      }
    );
    bot.stdout.on("data", (chunk) => {
      for (const line of chunk.toString().trim().split("\n")) {
        try {
          logs.push(JSON.parse(line));
          if (process.env.SMOKE_TRACE) console.error(line);
        } catch {}
      }
    });
    bot.stderr.on("data", (chunk) => process.stderr.write(chunk));
    children.push(bot);
    return bot;
  };
  const stopBot = async (bot) => {
    if (bot.exitCode !== null) return;
    const exited = new Promise((resolve) => bot.once("exit", resolve));
    bot.kill("SIGTERM");
    await exited;
  };
  let bot = startBot();
  await deadline(
    () => logs.some((l) => l.event === "ready"),
    "bot did not start"
  );
  assert.equal(
    logs.find((l) => l.event === "ready").blockTimeMs,
    200,
    "native cadence must be detected"
  );
  for (let step = 1; step <= (overlap ? 150 : 100); step++) {
    await sleep(200);
    await provider.send("evm_mine", [t + Math.floor(step / 5)]);
    latestNativeMs = t * 1000 + step * 200;
    nativeTimes.set(
      (await provider.send("eth_getBlockByNumber", ["latest", false])).number,
      latestNativeMs
    );
    if (overlap && step === 65) await up.stopCampaign({ gasLimit: 1500000 });
    if (!overlap && !late && step === 55) {
      assert.ok(
        !(await up.round(1)).startBlock.isZero(),
        "native cutoff capture missing"
      );
      await stopBot(bot);
      // The stopped Campaign has no current pointer; its seed is now 55 blocks old.
      // Restart must recover it by elapsed time, not the former 32-block horizon.
      assert.equal((await up.currentRound()).toString(), "0");
      bot = startBot();
    }
  }
  // Captures keep their original exact deadlines. Slow RPCs may take longer
  // to drain discovery/settlement work after the final boundary has passed.
  if (!late) {
    for (let extra = 1; extra <= 150; extra++) {
      const ids = overlap ? [1, 2, 3] : [1];
      const results = await Promise.all(
        ids.flatMap((id) => [up.round(id), pot.round(id)])
      );
      if (results.every((r) => r.result !== 0)) break;
      await sleep(200);
      latestNativeMs += 200;
      await provider.send("evm_mine", [Math.floor(latestNativeMs / 1000)]);
      nativeTimes.set(
        (await provider.send("eth_getBlockByNumber", ["latest", false])).number,
        latestNativeMs
      );
    }
  }
  await stopBot(bot);
  if (late) {
    assert.equal(bot.exitCode, 1, "late capture must stop the process");
    const failure = logs.find((l) => l.event === "capture_failed");
    assert.ok(
      failure,
      "late receipt must produce an actionable capture failure"
    );
    assert.equal(failure.reason, "OutsideBoundary");
    assert.equal(failure.stopped, true);
    assert.equal(
      logs.filter((l) => l.event === "submitted").length,
      1,
      "a known failed capture must not be followed by further broadcasts"
    );
    console.log(
      "PASS: real late-inclusion revert stops the CLI after one capture and reports OutsideBoundary"
    );
  } else {
    assert.equal(
      (await up.round(1)).result,
      3,
      `native UpDown must settle Tie, not refund; events=${JSON.stringify(
        logs
      )}`
    );
    assert.equal(
      (await pot.round(1)).result,
      1,
      `native threshold must settle Yes, not refund; events=${JSON.stringify(
        logs
      )}`
    );
    assert.equal(
      logs.some((l) => l.event === "reverted"),
      false,
      "native captures must not execute early"
    );
    if (overlap) {
      for (const id of [1, 2, 3]) {
        assert.equal(
          (await up.round(id)).result,
          3,
          `overlap UpDown round ${id}`
        );
        assert.equal(
          (await pot.round(id)).result,
          1,
          `overlap threshold round ${id}`
        );
      }
      assert.ok(
        logs.some((l) => l.event === "capture_prepared" && l.count === 3),
        "three simultaneous captures were not exercised"
      );
    }
    console.log(
      overlap
        ? `PASS: 200ms overlap: three simultaneous captures and three settled Rounds per contract with ${latency}ms RPC latency`
        : `PASS: 200ms canonical blocks with repeated seconds, ${latency}ms RPC latency and restart past 32 blocks`
    );
  }
} finally {
  for (const child of children) child.kill("SIGTERM");
  anvil.kill("SIGTERM");
  proxy.closeAllConnections();
  proxy.close();
}

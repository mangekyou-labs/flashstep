import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { createServer } from "node:http";
import { ethers } from "ethers";

// Executable local-chain smoke check; no JS test runner or external network.
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const port = 19000 + Math.floor(Math.random() * 1000);
const url = `http://127.0.0.1:${port}`;
const anvil = spawn("anvil", ["--port", String(port), "--silent"], {
  stdio: "ignore",
});
const provider = new ethers.providers.JsonRpcProvider(url);
provider.pollingInterval = 20;
const children = [];
const requestTimes = [];
const proxy = createServer(async (req, res) => {
  requestTimes.push(Date.now());
  let body = "";
  for await (const chunk of req) body += chunk;
  try {
    const reply = await fetch(url, {
      method: "POST",
      body,
      headers: { "content-type": "application/json" },
    });
    res.writeHead(reply.status, { "content-type": "application/json" });
    res.end(await reply.text());
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
    10,
    4,
    { gasLimit: 1500000, nonce }
  );
  await pot.seedRound(
    [
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("1"),
      ethers.BigNumber.from(10).pow(36).sub(1),
      10,
      4,
      t + 10,
      0,
      reader.address,
      ethers.constants.AddressZero,
    ],
    { gasLimit: 1500000, nonce: nonce + 1 }
  );
  await provider.send("evm_setNextBlockTimestamp", [t]);
  await provider.send("evm_mine", []);
  await up.stopCampaign({ gasLimit: 1500000, nonce: nonce + 2 });
  await pot.stopCampaign({ gasLimit: 1500000, nonce: nonce + 3 });
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
          SETTLE_REQUEST_INTERVAL_MS: "10",
          SETTLE_POLL_MS: "20",
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
  const bot = startBot();
  await deadline(
    () => logs.some((l) => l.event === "ready"),
    "bot did not start"
  );
  for (let offset = 2; offset <= 16; offset += 2) {
    await sleep(650);
    await provider.send("evm_setNextBlockTimestamp", [t + offset]);
    await provider.send("evm_mine", []);
  }
  await deadline(
    async () =>
      (await provider.send("eth_getTransactionCount", [
        await provider.getSigner(1).getAddress(),
        "pending",
      ])) === "0x5",
    "bot did not submit captures and settlements for both contracts"
  );
  await provider.send("evm_setNextBlockTimestamp", [t + 18]);
  await provider.send("evm_mine", []);
  assert.equal(
    (await up.round(1)).result,
    3,
    "up/down Round must settle as Tie, not refund"
  );
  assert.equal(
    (await pot.round(1)).result,
    1,
    "threshold Round must settle Yes, not refund"
  );
  await stopBot(bot);
  console.log(
    "PASS: unprivileged CLI captured and settled both real Round contracts on time"
  );

  // A restart must replay older escrow even when currentRound() is zero.
  await provider.send("evm_setAutomine", [true]);
  const up2 = await deploy("UpDownRounds", [
    payer,
    reader.address,
    ethers.constants.AddressZero,
    ethers.utils.parseEther("0.01"),
  ]);
  const pot2 = await deploy("ThresholdPots", [
    payer,
    reader.address,
    ethers.constants.AddressZero,
  ]);
  for (const c of [up2, pot2])
    await (
      await c.fund(ethers.utils.parseEther("10"), {
        value: ethers.utils.parseEther("10"),
      })
    ).wait();
  const t2 = (await provider.getBlock("latest")).timestamp + 10;
  await provider.send("evm_setAutomine", [false]);
  const n2 = await owner.getTransactionCount();
  await up2.seedRound(
    ethers.utils.parseEther("1"),
    ethers.utils.parseEther("1"),
    10,
    4,
    { gasLimit: 1500000, nonce: n2 }
  );
  await pot2.seedRound(
    [
      ethers.utils.parseEther("1"),
      ethers.utils.parseEther("1"),
      ethers.BigNumber.from(10).pow(36).sub(1),
      10,
      4,
      t2 + 10,
      0,
      reader.address,
      ethers.constants.AddressZero,
    ],
    { gasLimit: 1500000, nonce: n2 + 1 }
  );
  await provider.send("evm_setNextBlockTimestamp", [t2]);
  await provider.send("evm_mine", []);
  await up2.stopCampaign({ gasLimit: 1500000, nonce: n2 + 2 });
  await pot2.stopCampaign({ gasLimit: 1500000, nonce: n2 + 3 });
  const before = logs.filter((l) => l.event === "ready").length;
  const second = startBot(up2.address, pot2.address);
  await deadline(
    () => logs.filter((l) => l.event === "ready").length > before,
    "second bot did not start"
  );
  for (let offset = 2; offset <= 12; offset += 2) {
    await sleep(650);
    await provider.send("evm_setNextBlockTimestamp", [t2 + offset]);
    await provider.send("evm_mine", []);
  }
  await deadline(
    async () =>
      (await provider.send("eth_getTransactionCount", [
        await provider.getSigner(1).getAddress(),
        "pending",
      ])) === "0x8",
    "end captures not queued before restart"
  );
  await stopBot(second);
  const count = logs.filter((l) => l.event === "ready").length;
  const restarted = startBot(up2.address, pot2.address);
  await deadline(
    () => logs.filter((l) => l.event === "ready").length > count,
    "restart did not start"
  );
  await sleep(250);
  assert.equal(
    await provider.send("eth_getTransactionCount", [
      await provider.getSigner(1).getAddress(),
      "pending",
    ]),
    "0x8",
    "restart must wait for existing pending captures"
  );
  await provider.send("evm_setNextBlockTimestamp", [t2 + 14]);
  await provider.send("evm_mine", []);
  await deadline(
    async () =>
      (await provider.send("eth_getTransactionCount", [
        await provider.getSigner(1).getAddress(),
        "pending",
      ])) === "0xa",
    "restart did not recover unsettled Rounds"
  );
  await provider.send("evm_setNextBlockTimestamp", [t2 + 16]);
  await provider.send("evm_mine", []);
  assert.equal((await up2.round(1)).result, 3);
  assert.equal((await pot2.round(1)).result, 1);
  await stopBot(restarted);
  console.log(
    "PASS: restart recovered both stopped Campaigns from historical RoundSeeded events"
  );

  const readyCount = logs.filter((l) => l.event === "ready").length;
  const skipping = startBot(up2.address, pot2.address, {
    SETTLE_PRIVATE_KEY: ethers.Wallet.fromMnemonic(
      "test test test test test test test test test test test junk",
      "m/44'/60'/0'/0/2"
    ).privateKey,
  });
  await deadline(
    () => logs.filter((l) => l.event === "ready").length > readyCount,
    "skip bot did not start"
  );
  await sleep(650);
  await provider.send("evm_setNextBlockTimestamp", [t2 + 18]);
  await provider.send("evm_mine", []);
  await sleep(650);
  assert.equal(
    await provider.send("eth_getTransactionCount", [
      await provider.getSigner(1).getAddress(),
      "pending",
    ]),
    "0xa",
    "already-settled Rounds must not spend gas"
  );
  assert.equal(
    await provider.send("eth_getTransactionCount", [
      await provider.getSigner(2).getAddress(),
      "pending",
    ]),
    "0x0",
    "another bot must skip Rounds already settled by someone else"
  );
  await stopBot(skipping);
  assert.equal(
    logs.some((l) => l.event === "reverted"),
    false,
    "no bot transaction should revert"
  );
  for (let i = 1; i < requestTimes.length; i++)
    assert.ok(
      requestTimes[i] - requestTimes[i - 1] >= 7,
      "configured 10ms RPC pacing must apply to every request"
    );
  console.log(
    "PASS: settled Rounds skipped without transactions; configurable RPC proxy observed request pacing"
  );
  const invalid = startBot(up2.address, pot2.address, {
    SETTLE_REQUEST_INTERVAL_MS: "0",
  });
  const invalidExit = await new Promise((resolve) =>
    invalid.once("exit", resolve)
  );
  assert.equal(
    invalidExit,
    1,
    "invalid request-rate configuration must fail before running"
  );
  console.log("PASS: invalid request-rate configuration fails at startup");
} finally {
  for (const child of children) child.kill("SIGTERM");
  anvil.kill("SIGTERM");
  proxy.closeAllConnections();
  proxy.close();
}

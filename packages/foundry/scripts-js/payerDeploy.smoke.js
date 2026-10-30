import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";
import { ethers } from "ethers";

// Local end-to-end run: the payer deploy driver, then the settle bot, then the contract views the page reads.
// Runs on a throwaway anvil it starts itself. The payer is anvil account 1, so a default sender cannot pass for it.
// No JS test runner or external network.
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const ROOT = fileURLToPath(new URL("..", import.meta.url));
const MNEMONIC = "test test test test test test test test test test test junk";
// SMOKE_PORT pins the port and SMOKE_HOLD_SECONDS keeps the chain up afterwards, so the page can be pointed at it by hand.
const port = Number(process.env.SMOKE_PORT) || 19000 + Math.floor(Math.random() * 1000);
const url = `http://127.0.0.1:${port}`;
const foundryBin = `${homedir()}/.foundry/bin`;
const env = { ...process.env, PATH: `${foundryBin}:${process.env.PATH}` };
const anvil = spawn("anvil", ["--port", String(port), "--silent"], { env, stdio: "ignore" });
const provider = new ethers.providers.JsonRpcProvider(url);
provider.pollingInterval = 20;
const children = [];

const artifact = (file, name) => JSON.parse(readFileSync(new URL(`../out/${file}.sol/${name}.json`, import.meta.url)));
const deadline = async (fn, message, attempts = 200) => {
  for (let i = 0; i < attempts; i++) {
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

  const developer = provider.getSigner(0); // deploys the fixtures; must end up holding nothing
  const payerSigner = provider.getSigner(1);
  const payer = await payerSigner.getAddress();
  const developerAddress = await developer.getAddress();
  const botKey = ethers.Wallet.fromMnemonic(MNEMONIC, "m/44'/60'/0'/0/3").privateKey;
  const botAddress = new ethers.Wallet(botKey).address;

  const deploy = async (file, name, args) => {
    const a = artifact(file, name);
    const contract = await new ethers.ContractFactory(a.abi, a.bytecode.object, developer).deploy(...args);
    await contract.deployed();
    return contract;
  };

  // Fixtures standing in for the real Base pool: a quote and stake token, a base token, a v3 factory and a pool.
  const quote = await deploy("StakeTokenMock", "StakeTokenMock", []);
  const base = await deploy("MockBasePool", "MockReadingToken", [18, ethers.constants.WeiPerEther]);
  const factory = await deploy("MockUniswapV3", "MockV3Factory", []);
  const [token0, token1] =
    base.address.toLowerCase() < quote.address.toLowerCase()
      ? [base.address, quote.address]
      : [quote.address, base.address];
  const pool = await deploy("MockUniswapV3", "MockV3Pool", [factory.address, token0, token1, 500]);
  await (await pool.write(0)).wait();
  await (await factory.setPool(token0, token1, 500, pool.address)).wait();
  const poolDepth = ethers.utils.parseEther("13633808");
  const payerFunds = ethers.utils.parseEther("100");
  await (await quote.setBalance(pool.address, poolDepth)).wait();
  await (await quote.setBalance(payer, payerFunds)).wait();

  const e18 = n => ethers.utils.parseEther(String(n)).toString();
  const settings = {
    payer,
    stakeToken: quote.address,
    pool: pool.address,
    baseToken: base.address,
    poolFee: 500,
    poolFactory: factory.address,
    lookbackSeconds: 4,
    // The Stake cap rule is enforced: these caps are under what it allows for a 4 second Window.
    allowStakeCapAboveRule: false,
    updown: {
      payout: e18(1),
      seed: e18(1),
      stakeCap: e18("0.5"),
      tradingSeconds: 10,
      windowSeconds: 4,
      durationSeconds: 0,
      funding: e18(10),
    },
    threshold: {
      metric: "Price",
      threshold: ethers.BigNumber.from(10).pow(36).sub(1).toString(), // above any price here, so the Round settles Yes
      openingStake: e18("0.1"),
      stakeCap: e18("0.5"),
      tradingSeconds: 10,
      windowSeconds: 4,
      durationSeconds: 0,
      funding: e18(10),
      supplyMode: "Unsupported",
      fixedSupply: "0",
    },
  };
  mkdirSync(new URL("../cache-payer/", import.meta.url), { recursive: true });
  const configPath = fileURLToPath(new URL(`../cache-payer/e2e-config-${port}.json`, import.meta.url));
  const outPath = fileURLToPath(new URL(`../cache-payer/e2e-deploy-${port}.json`, import.meta.url));
  writeFileSync(configPath, JSON.stringify(settings, null, 2));

  const driverPath = fileURLToPath(new URL("payerDeploy.js", import.meta.url));
  const runDriver = (args, extraEnv = {}, input = "") =>
    spawnSync(process.execPath, [driverPath, ...args], {
      cwd: ROOT,
      env: { ...env, ...extraEnv },
      encoding: "utf8",
      input,
    });

  // Runs the driver and types each reply once its prompt has appeared on stdout. Resolves when the driver exits.
  const runDriverAnswering = (args, extraEnv, replies) =>
    new Promise((resolve, reject) => {
      const child = spawn(process.execPath, [driverPath, ...args], {
        cwd: ROOT,
        env: { ...env, ...extraEnv },
        stdio: ["pipe", "pipe", "pipe"],
      });
      children.push(child);
      let stdout = "";
      let stderr = "";
      let next = 0;
      const timer = setTimeout(() => {
        child.kill("SIGTERM");
        reject(new Error(`The driver did not finish. Output so far:\n${stdout}`));
      }, 120_000);
      child.stdout.on("data", chunk => {
        stdout += chunk;
        while (next < replies.length && replies[next][0].test(stdout)) {
          child.stdin.write(replies[next][1]);
          stdout = stdout.replace(replies[next][0], "");
          next++;
        }
      });
      child.stderr.on("data", chunk => (stderr += chunk));
      child.on("close", status => {
        clearTimeout(timer);
        resolve({ status, stdout, stderr });
      });
    });

  // 0. The gate. A raw key is refused; anything but a typed yes sends nothing; the skip works on a local chain only.
  const refusedKey = runDriver(["--config", configPath, "--network", url, "--private-key", "0x01"]);
  assert.notEqual(refusedKey.status, 0);
  assert.match(refusedKey.stderr, /never accepts --private-key/);

  const declinedOut = fileURLToPath(new URL(`../cache-payer/e2e-declined-${port}.json`, import.meta.url));
  const declined = runDriver(
    ["--config", configPath, "--network", url, "--local-sender", payer],
    { PAYER_DEPLOY_OUT: declinedOut },
    "no\n",
  );
  assert.notEqual(declined.status, 0, "anything but a typed yes stops the run");
  assert.match(declined.stdout, /Type "yes" to continue/);
  assert.equal(existsSync(declinedOut), false, "nothing was deployed after a no");
  assert.equal(await provider.getTransactionCount(payer), 0, "the payer sent nothing after a no");

  // The pre-funding gate (gate 2). The first answer is yes, so the contracts are deployed; the second is no, so
  // nothing may be funded or seeded. Each answer is typed only after its prompt appears, as a person would: a
  // readline closed after the first answer would otherwise swallow a second line piped in at the start.
  const gateTwoOut = fileURLToPath(new URL(`../cache-payer/e2e-gate2-${port}.json`, import.meta.url));
  const answered = await runDriverAnswering(
    ["--config", configPath, "--network", url, "--local-sender", payer],
    { PAYER_DEPLOY_OUT: gateTwoOut },
    [
      [/Deploy the contracts from the payer wallet now\? Type "yes" to continue: /, "yes\n"],
      [/Send the funds and start both Campaigns now\? Type "yes" to continue: /, "no\n"],
    ],
  );
  assert.notEqual(answered.status, 0, "a no at the pre-funding gate stops the run");
  assert.match(answered.stderr, /Not confirmed\. Nothing was sent\./);
  assert.equal(existsSync(gateTwoOut), true, "the first yes deployed the contracts");
  const gateTwo = JSON.parse(readFileSync(gateTwoOut, "utf8"));
  assert.equal((await quote.balanceOf(payer)).toString(), payerFunds.toString(), "the payer funded nothing after a no");
  assert.equal((await quote.balanceOf(gateTwo.upDown)).toString(), "0", "UpDownRounds holds no tokens after a no");
  assert.equal((await quote.balanceOf(gateTwo.threshold)).toString(), "0", "ThresholdPots holds no tokens after a no");
  for (const [file, name, address] of [
    ["UpDownRounds", "UpDownRounds", gateTwo.upDown],
    ["ThresholdPots", "ThresholdPots", gateTwo.threshold],
  ]) {
    const unfunded = new ethers.Contract(address, artifact(file, name).abi, provider);
    assert.equal((await unfunded.fundingBalance()).toString(), "0", `${name} has no funding after a no`);
    assert.equal((await unfunded.currentRound()).toString(), "0", `${name} has no running Round after a no`);
  }

  console.log("PASS: a no at the pre-funding gate leaves the deployed contracts unfunded and unseeded");

  const otherPort = port + 1000;
  const otherAnvil = spawn("anvil", ["--port", String(otherPort), "--silent", "--chain-id", "8453"], {
    env,
    stdio: "ignore",
  });
  children.push(otherAnvil);
  const other = new ethers.providers.JsonRpcProvider(`http://127.0.0.1:${otherPort}`);
  await deadline(async () => {
    try {
      await other.send("eth_chainId", []);
      return true;
    } catch {
      return false;
    }
  }, "Second anvil did not start");
  const refusedSkip = runDriver(
    [
      "--config",
      configPath,
      "--network",
      `http://127.0.0.1:${otherPort}`,
      "--local-sender",
      payer,
      "--skip-confirmation",
    ],
    { PAYER_DEPLOY_OUT: declinedOut },
  );
  assert.notEqual(refusedSkip.status, 0, "the confirmation cannot be skipped on a chain that is not 31337");
  assert.match(refusedSkip.stderr, /Stopped/);
  assert.equal(existsSync(declinedOut), false);
  console.log("PASS: a raw key, a missing yes and a skip on a non-local chain are all refused");

  // 1. The driver, as the payer, with the confirmation gate skipped (allowed only for this loopback chain).
  const driver = spawnSync(
    process.execPath,
    [
      fileURLToPath(new URL("payerDeploy.js", import.meta.url)),
      "--config",
      configPath,
      "--network",
      url,
      "--local-sender",
      payer,
      "--skip-confirmation",
    ],
    { cwd: ROOT, env: { ...env, PAYER_DEPLOY_OUT: outPath }, encoding: "utf8" },
  );
  process.stdout.write(driver.stdout);
  process.stderr.write(driver.stderr);
  assert.equal(driver.status, 0, "the payer deploy driver must succeed");
  assert.match(driver.stdout, /Estimated deploy/, "the driver prints the priced gas estimate");
  assert.match(
    driver.stdout,
    /Funds leaving the payer, to checksummed destinations/,
    "the driver prints the funding table",
  );
  assert.match(driver.stdout, /confirmation skipped: local chain only/);

  const deployed = JSON.parse(readFileSync(outPath, "utf8"));
  const up = new ethers.Contract(deployed.upDown, artifact("UpDownRounds", "UpDownRounds").abi, provider);
  const pot = new ethers.Contract(deployed.threshold, artifact("ThresholdPots", "ThresholdPots").abi, provider);

  // Ownership: the payer owns both and the developer holds nothing.
  assert.equal(await up.owner(), payer, "payer owns UpDownRounds");
  assert.equal(await pot.owner(), payer, "payer owns ThresholdPots");
  assert.notEqual(developerAddress, payer);
  assert.equal((await quote.balanceOf(developerAddress)).toString(), "0", "the developer holds no stake tokens");
  assert.equal(
    (await quote.balanceOf(payer)).toString(),
    payerFunds.sub(e18(20)).toString(),
    "the payer paid both fundings",
  );
  assert.equal((await quote.balanceOf(up.address)).toString(), e18(10));
  assert.equal((await quote.balanceOf(pot.address)).toString(), e18(10));
  console.log("PASS: the payer owns both contracts, paid for both, and the developer holds nothing");

  // 2. The settle bot settles both Rounds. Blocks are stepped by hand so the run takes seconds.
  const r1 = await up.round(1);
  const p1 = await pot.round(1);
  assert.equal(r1.payer, payer);
  assert.equal(p1.payer, payer);
  const logs = [];
  const bot = spawn(process.execPath, [fileURLToPath(new URL("settleBot.js", import.meta.url))], {
    env: {
      ...env,
      SETTLE_RPC_URL: url,
      SETTLE_PRIVATE_KEY: botKey,
      SETTLE_UPDOWN_ADDRESS: up.address,
      SETTLE_THRESHOLD_ADDRESS: pot.address,
      SETTLE_FROM_BLOCK: "0",
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  children.push(bot);
  bot.stdout.on("data", chunk => {
    for (const line of chunk.toString().trim().split("\n")) {
      try {
        logs.push(JSON.parse(line));
      } catch {}
    }
  });
  bot.stderr.on("data", chunk => process.stderr.write(chunk));
  await deadline(() => logs.some(l => l.event === "ready"), "bot did not start");

  await provider.send("evm_setAutomine", [false]);
  let now = (await provider.getBlock("latest")).timestamp;
  const end = Math.max(r1.windowEnd.toNumber(), p1.windowEnd.toNumber());
  for (let step = 0; step < 40; step++) {
    await sleep(650);
    now += 2;
    await provider.send("evm_setNextBlockTimestamp", [now]);
    await provider.send("evm_mine", []);
    if (now > end + 4 && (await up.round(1)).result !== 0 && (await pot.round(1)).result !== 0) break;
  }
  const upResult = (await up.round(1)).result;
  const potResult = (await pot.round(1)).result;
  assert.equal(upResult, 3, "a flat price settles the up/down Round as a Tie");
  assert.equal(potResult, 1, "the price is below the threshold, so the Threshold Round settles Yes");
  assert.equal(
    logs.some(l => l.event === "reverted"),
    false,
    "no bot transaction reverted",
  );
  assert.notEqual(botAddress, payer, "the bot is not the payer");
  assert.equal(
    (await provider.getBalance(botAddress)).lt(ethers.utils.parseEther("10000")),
    true,
    "the bot paid its own gas",
  );
  console.log("PASS: the settle bot, with its own key, settled both Rounds of the payer's contracts");

  // 3. What the page reads. The page takes these two addresses from its environment and calls these views.
  await provider.send("evm_setAutomine", [true]);
  const pageEnv = {
    NEXT_PUBLIC_ROUNDS_ADDRESS: ethers.utils.getAddress(up.address),
    NEXT_PUBLIC_THRESHOLD_ADDRESS: ethers.utils.getAddress(pot.address),
  };
  const current = await up.currentRound();
  assert.ok(current.gte(2), "the page follows currentRound to the next Round");
  const next = current.toString();
  assert.equal(await up.phase(next).then(x => Number(x) >= 0), true);
  assert.equal((await up.chanceCents(next)).toNumber() > 0, true, "the page can show a chance");
  assert.equal((await up.PAYOUT()).toString(), e18(1));
  assert.equal(await pot.i_stakeToken(), quote.address);
  assert.equal(await up.i_stakeToken(), quote.address);
  console.log("PASS: the page's contract views answer at the deployed addresses");
  console.log(JSON.stringify(pageEnv));
  const hold = Number(process.env.SMOKE_HOLD_SECONDS) || 0;
  if (hold > 0) {
    console.log(`Holding the chain at ${url} for ${hold} seconds`);
    await sleep(hold * 1000);
  }
} finally {
  for (const child of children) child.kill("SIGTERM");
  anvil.kill("SIGTERM");
}

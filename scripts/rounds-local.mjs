// Local-chain fixture only. Uses Anvil's unlocked accounts; never loads a private key.
import { readFile, mkdir, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const require = createRequire(new URL("packages/nextjs/package.json", root));
const { createPublicClient, createWalletClient, http, parseEther, zeroAddress, isAddress } = require("viem");
const { foundry } = require("viem/chains");
const rpcUrl = process.env.ROUNDS_LOCAL_RPC || "http://127.0.0.1:8545";
const endpoint = new URL(rpcUrl);
if (!["127.0.0.1", "localhost", "[::1]"].includes(endpoint.hostname)) {
  throw new Error("This fixture runs only against localhost Anvil.");
}
const client = createPublicClient({ chain: foundry, transport: http(rpcUrl), pollingInterval: 100 });
const rpc = (method, params = []) => client.request({ method, params });
if (await client.getChainId() !== foundry.id || !(await rpc("web3_clientVersion")).toLowerCase().includes("anvil")) {
  throw new Error("Expected local Anvil on chain 31337.");
}
const [payer] = await rpc("eth_accounts");
const wallet = createWalletClient({ account: payer, chain: foundry, transport: http(rpcUrl) });
const artifact = async (file, name) => JSON.parse(await readFile(new URL(`packages/foundry/out/${file}.sol/${name}.json`, root), "utf8"));
const roundsArtifact = await artifact("UpDownRounds", "UpDownRounds");
const poolArtifact = await artifact("MockBasePool", "MockBasePool");
const stateFile = new URL("output/rounds-local.json", root);
async function receipt(hash) {
  const result = await client.waitForTransactionReceipt({ hash });
  if (result.status !== "success") throw new Error(`Local transaction reverted: ${hash}`);
  return result;
}
async function deploy(file, name, args) {
  const built = await artifact(file, name);
  const result = await receipt(await wallet.deployContract({ abi: built.abi, bytecode: built.bytecode.object, args, gas: 8_000_000n }));
  if (!result.contractAddress) throw new Error(`No contract address for ${name}`);
  return result.contractAddress;
}
async function write(address, abi, functionName, args = [], value = 0n) {
  return receipt(await wallet.writeContract({ address, abi, functionName, args, value, gas: 6_000_000n }));
}
async function timestamp(next) {
  const latest = await client.getBlock();
  if (latest.timestamp >= next) throw new Error(`Boundary ${next} has already passed (chain time ${latest.timestamp}). Set up a fresh fixture.`);
  await rpc("evm_setNextBlockTimestamp", [Number(next)]);
}
const [command, argument, outcome] = process.argv.slice(2);
if (command === "setup") {
  await rpc("anvil_setIntervalMining", [0]);
  await rpc("evm_setAutomine", [true]);
  // Advance one second per transaction, independent of wall clock and browser speed.
  await rpc("anvil_setBlockTimestampInterval", [1]);
  const base = await deploy("MockBasePool", "MockReadingToken", [18, parseEther("1000000")]);
  const quote = await deploy("MockBasePool", "MockReadingToken", [18, parseEther("1000000")]);
  const pool = await deploy("MockBasePool", "MockBasePool", [base, quote]);
  await write(pool, poolArtifact.abi, "write", [0]);
  const reader = await deploy("BasePoolReader", "BasePoolReader", [pool, base, 4]);
  const rounds = await deploy("UpDownRounds", "UpDownRounds", [payer, reader, zeroAddress, parseEther("0.01")]);
  await write(rounds, roundsArtifact.abi, "fund", [parseEther("10")], parseEther("10"));
  await write(rounds, roundsArtifact.abi, "seedRound", [parseEther("1"), parseEther("0.1"), 30, 4]);
  await mkdir(new URL("output/", root), { recursive: true });
  await writeFile(stateFile, JSON.stringify({ rpcUrl, payer, base, quote, pool, reader, rounds }, null, 2) + "\n");
  console.log(`Fixture: ${fileURLToPath(stateFile)}\nNEXT_PUBLIC_ROUNDS_ADDRESS=${rounds}\nOpen /rounds?brand=DEGEN`);
} else if (command === "fund-player") {
  if (!isAddress(argument)) throw new Error("Pass the local burner wallet address.");
  await rpc("anvil_setBalance", [argument, `0x${parseEther("10").toString(16)}`]);
  console.log(`Funded local player ${argument} with test ETH.`);
} else if (command === "settle" || command === "cutoff") {
  const state = JSON.parse(await readFile(stateFile, "utf8"));
  const roundId = BigInt(argument || "1");
  const r = await client.readContract({ address: state.rounds, abi: roundsArtifact.abi, functionName: "round", args: [roundId] });
  if (r.result !== 0) throw new Error("Round already settled.");
  if (r.startBlock === 0n) {
    await timestamp(r.cutoff);
    await write(state.rounds, roundsArtifact.abi, "captureBoundary", [roundId]);
  }
  if (command === "settle") {
    // A higher pool tick during the Window makes Up win; `tie` leaves the tick unchanged.
    // Both Readings still use the real reader.
    const tie = outcome === "tie";
    if (!tie) await write(state.pool, poolArtifact.abi, "write", [100]);
    await timestamp(r.windowEnd);
    await write(state.rounds, roundsArtifact.abi, "captureBoundary", [roundId]);
    const result = await write(state.rounds, roundsArtifact.abi, "settle", [roundId]);
    console.log(`Round ${roundId} settled ${tie ? "Tie" : "Up"}: ${result.transactionHash}`);
  } else {
    console.log(`Round ${roundId} entered its Window; the next Round is trading.`);
  }
} else {
  throw new Error("Usage: node scripts/rounds-local.mjs setup | fund-player <address> | cutoff [roundId] | settle [roundId] [tie]");
}

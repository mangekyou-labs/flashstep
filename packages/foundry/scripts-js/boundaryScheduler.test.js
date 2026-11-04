import assert from "node:assert/strict";
import test from "node:test";
import { ethers } from "ethers";
import { createBoundaryScheduler } from "./boundaryScheduler.js";
import {
  broadcastTransaction,
  nextAvailableNonce,
} from "./transactionSender.js";
const c = { name: "UpDownRounds", address: "0x01" };
const key = `${c.address}:1:captureBoundary:1000`;
const args = (overrides = {}) => ({
  c,
  id: "1",
  action: "captureBoundary",
  boundary: 1000,
  nonce: 0,
  raw: "0x01",
  blockTimeMs: 200,
  pending: new Map(),
  log: () => {},
  ...overrides,
});
test("lagging providers cannot reallocate unresolved local nonces", () => {
  const pending = new Map([["capture", { nonce: 5 }]]);
  assert.equal(nextAvailableNonce(0, pending), 6);
  assert.equal(nextAvailableNonce(9, pending), 9);
  assert.equal(nextAvailableNonce(0, new Map()), 0);
});
test("expired retries use fresh timestamps and never broadcast", async () => {
  const pending = new Map([[key, { nonce: 0 }]]);
  const methods = [];
  const sent = await broadcastTransaction(
    args({
      pending,
      rpc: async (method) => {
        methods.push(method);
        return { timestamp: 1001 };
      },
    })
  );
  assert.equal(sent, false);
  assert.deepEqual(methods, ["eth_getBlockByNumber"]);
  assert.equal(pending.size, 0);
});
test("each simultaneous capture rechecks the chain before sending", async () => {
  let now = 1000;
  let sends = 0;
  const pending = new Map();
  const rpc = async (method) => {
    if (method === "eth_getBlockByNumber") return { timestamp: now };
    assert.equal(method, "eth_sendRawTransaction");
    sends++;
    now++;
  };
  assert.equal(await broadcastTransaction(args({ rpc, pending })), true);
  assert.equal(
    await broadcastTransaction(
      args({ rpc, pending, id: "2", nonce: 1, raw: "0x02" })
    ),
    false
  );
  assert.equal(sends, 1);
  assert.equal(pending.size, 1);
});
test("ambiguous sends reserve their nonce without logging transport details", async () => {
  const pending = new Map();
  const events = [];
  await broadcastTransaction(
    args({
      pending,
      rpc: async (method) => {
        if (method === "eth_getBlockByNumber") return { timestamp: 1000 };
        throw new Error("private transport detail");
      },
      log: (event, fields) => events.push({ event, ...fields }),
    })
  );
  assert.equal(pending.get(key).uncertain, true);
  assert.equal(pending.get(key).hash, ethers.utils.keccak256("0x01"));
  assert.equal(nextAvailableNonce(0, pending), 1);
  assert.equal(events[0].event, "broadcast_uncertain");
  assert.equal(
    JSON.stringify(events).includes("private transport detail"),
    false
  );
});
test("definite rejection releases the nonce", async () => {
  const pending = new Map();
  await broadcastTransaction(
    args({
      pending,
      rpc: async (method) => {
        if (method === "eth_getBlockByNumber") return { timestamp: 1000 };
        throw Object.assign(new Error("rejected"), { rejected: true });
      },
    })
  );
  assert.equal(pending.size, 0);
});
test("legacy captures still broadcast one two-second block ahead", async () => {
  let sends = 0;
  const rpc = async (method) => {
    if (method === "eth_getBlockByNumber") return { timestamp: 998 };
    sends++;
  };
  assert.equal(
    await broadcastTransaction(args({ rpc, blockTimeMs: 2000 })),
    true
  );
  assert.equal(sends, 1);
});
test("scheduler pauses remaining captures after uncertain acceptance", async () => {
  const r = {
    result: 0,
    cutoff: ethers.BigNumber.from(1000),
    windowEnd: ethers.BigNumber.from(1100),
    startBlock: ethers.constants.Zero,
    endBlock: ethers.constants.Zero,
  };
  const contracts = [1, 2].map((n) => ({
    name: "UpDownRounds",
    address: `0x0${n}`,
    rounds: new Set(["1"]),
    roundData: new Map([["1", { ...r }]]),
    iface: { encodeFunctionData: () => "0x01" },
  }));
  // Reproduce restart preemption before the second contract was discovered.
  contracts[1].rounds.clear();
  contracts[1].roundData.clear();
  let scheduler;
  let headReads = 0;
  let sends = 0;
  const signedNonces = [];
  const pending = new Map();
  const rpc = async (method) => {
    if (method === "eth_getBlockByNumber") {
      const block = { timestamp: ++headReads >= 2 ? 1000 : 997 };
      scheduler.observe(block);
      return block;
    }
    if (method === "eth_gasPrice") return "0x1";
    if (method === "eth_getTransactionCount") return "0x0";
    assert.equal(method, "eth_sendRawTransaction");
    sends++;
    throw new Error("timeout after possible acceptance");
  };
  scheduler = createBoundaryScheduler({
    contracts,
    rpc,
    call: async (_c, method) => [
      method === "currentRound" ? ethers.constants.One : r,
    ],
    chainId: 84532,
    gasLimit: 100000,
    pending,
    log: () => {},
    sleep: async () => {},
    isRunning: () => true,
    poll: 1,
    wallet: {
      address: "0x03",
      signTransaction: async ({ nonce }) => {
        signedNonces.push(nonce);
        return `0x0${nonce + 1}`;
      },
    },
    broadcast: (contract, id, action, boundary, nonce, raw) =>
      broadcastTransaction(
        args({
          c: contract,
          id,
          action,
          boundary,
          nonce,
          raw,
          rpc,
          pending,
        })
      ),
  });
  scheduler.observe({ timestamp: 997 });
  await scheduler.service();
  await scheduler.service();
  assert.deepEqual(signedNonces, [0, 1]);
  assert.equal(sends, 1);
  assert.equal(pending.size, 1);
  assert.equal([...pending.values()][0].uncertain, true);
});

test("expired lower captures pause allocations while higher nonces remain pending", async () => {
  const pending = new Map([
    [key, { nonce: 0, hash: "0x01" }],
    ["higher", { nonce: 1 }],
  ]);
  const events = [];
  let sends = 0;
  const rpc = async (method) => {
    if (method === "eth_getBlockByNumber") return { timestamp: 1001 };
    sends++;
  };
  assert.equal(
    await broadcastTransaction(
      args({ rpc, pending, log: (event) => events.push(event) })
    ),
    false
  );
  assert.equal(sends, 0);
  assert.equal(pending.get(key).uncertain, true);
  assert.equal(pending.get(key).expired, true);
  assert.ok(events.includes("nonce_gap"));
  pending.delete("higher");
  await broadcastTransaction(args({ rpc, pending }));
  assert.equal(pending.size, 0);
});

test("a rejected retry cannot abandon a nonce with higher queued transactions", async () => {
  const pending = new Map([
    [key, { nonce: 0 }],
    ["higher", { nonce: 1 }],
  ]);
  await broadcastTransaction(
    args({
      pending,
      rpc: async (method) => {
        if (method === "eth_getBlockByNumber") return { timestamp: 1000 };
        throw Object.assign(new Error("rejected"), { rejected: true });
      },
    })
  );
  assert.equal(pending.get(key).uncertain, true);
  assert.equal(pending.size, 2);
});

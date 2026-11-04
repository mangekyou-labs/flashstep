import assert from "node:assert/strict";
import test from "node:test";
import { ethers } from "ethers";
import {
  broadcastCaptureGroup,
  broadcastTransaction,
} from "./transactionSender.js";
const prepared = [0, 1, 2].map((nonce) => ({
  c: { address: `0x0${nonce + 1}`, name: "UpDownRounds" },
  id: "1",
  nonce,
  raw: `0x0${nonce + 1}`,
}));
const hash = (index) => ethers.utils.keccak256(prepared[index].raw);
const head = { timestamp: 999, timestampMs: 999800, rpcMs: 300 };
async function run(rpcBatch, extra = {}) {
  const pending = new Map();
  const logs = [];
  const sent = await broadcastCaptureGroup({
    prepared,
    boundary: 1000,
    head,
    pending,
    rpcBatch,
    log: (event, fields) => logs.push({ event, ...fields }),
    ...extra,
  });
  return { sent, pending, logs };
}
test("capture group reserves every nonce before one submission request", async () => {
  const pending = new Map();
  let batches = 0;
  const result = await run(
    async (calls) => {
      batches++;
      assert.equal(pending.size, 3);
      assert.deepEqual(
        calls.map((c) => c.method),
        Array(3).fill("eth_sendRawTransaction")
      );
      return calls.map((_, index) => ({ result: hash(index) }));
    },
    { pending }
  );
  assert.equal(result.sent, true);
  assert.equal(batches, 1);
  assert.equal(result.logs.filter((l) => l.event === "submitted").length, 3);
  assert.ok([...pending.values()].every((tx) => !tx.uncertain));
});
test("a rejected lower nonce with an accepted higher nonce pauses the entire group", async () => {
  const result = await run(async () => [
    {
      error: Object.assign(new Error("private provider text"), {
        rejected: true,
        rpcCode: -32000,
      }),
    },
    { result: hash(1) },
    { result: hash(2) },
  ]);
  assert.equal(result.sent, false);
  assert.equal(result.pending.size, 3);
  assert.ok([...result.pending.values()].every((tx) => tx.uncertain));
  assert.equal(
    JSON.stringify(result.logs).includes("private provider text"),
    false
  );
  let freshBatches = 0;
  const next = await run(
    async () => {
      freshBatches++;
    },
    { pending: result.pending }
  );
  assert.equal(next.sent, false);
  assert.equal(freshBatches, 0);
});
for (const [name, response] of [
  [
    "transport failure",
    async () => {
      throw new Error("private URL");
    },
  ],
  ["missing member", async () => [{ result: hash(0) }]],
  ["mismatched hash", async () => prepared.map(() => ({ result: hash(0) }))],
])
  test(`${name} conservatively retains all capture nonces`, async () => {
    const result = await run(response);
    assert.equal(result.sent, false);
    assert.equal(result.pending.size, 3);
    assert.ok([...result.pending.values()].every((tx) => tx.uncertain));
    assert.equal(
      result.logs.some((l) => l.event === "submitted"),
      false
    );
  });
test("late head with a measured round trip leaves insufficient submission margin", async () => {
  let sends = 0;
  const result = await run(
    async () => {
      sends++;
    },
    { head: { timestamp: 1000, timestampMs: 1000600, rpcMs: 300 } }
  );
  assert.equal(result.sent, false);
  assert.equal(sends, 0);
  assert.equal(result.pending.size, 0);
  assert.equal(result.logs[0].reason, "insufficient_margin");
});

test("individual native retry also rejects insufficient measured margin", async () => {
  let sends = 0;
  const result = await broadcastTransaction({
    ...prepared[0],
    action: "captureBoundary",
    boundary: 1000,
    blockTimeMs: 200,
    rpc: async (method) => {
      if (method === "eth_getBlockByNumber")
        return { timestamp: 1000, timestampMs: 1000600, rpcMs: 300 };
      sends++;
    },
    pending: new Map(),
    log: () => {},
  });
  assert.equal(result, false);
  assert.equal(sends, 0);
});

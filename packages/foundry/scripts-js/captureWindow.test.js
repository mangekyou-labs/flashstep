import assert from "node:assert/strict";
import test from "node:test";
import { broadcastTransaction } from "./transactionSender.js";
const boundary = 1000;
const c = { name: "UpDownRounds", address: "0x01" };
async function sendAt(timestampMs) {
  let sends = 0;
  const sent = await broadcastTransaction({
    c,
    id: "1",
    action: "captureBoundary",
    boundary,
    nonce: 0,
    raw: "0x01",
    blockTimeMs: 200,
    pending: new Map(),
    log: () => {},
    rpc: async (method) => {
      if (method === "eth_getBlockByNumber")
        return { timestamp: Math.floor(timestampMs / 1000), timestampMs };
      sends++;
      return "0x01";
    },
  });
  return { sent, sends };
}
test("last native block before cutoff can target the first block of the correct second", async () => {
  assert.deepEqual(await sendAt(999800), { sent: true, sends: 1 });
});
test("last native block of cutoff second cannot target that second anymore", async () => {
  assert.deepEqual(await sendAt(1000800), { sent: false, sends: 0 });
});
test("native phase earlier than the final pre-boundary block cannot send early", async () => {
  assert.deepEqual(await sendAt(999600), { sent: false, sends: 0 });
});

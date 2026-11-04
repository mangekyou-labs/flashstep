import { ethers } from "ethers";
import { captureState } from "./captureWindow.js";

// Providers can lag their own send acknowledgement. Locally unresolved nonces
// remain reserved even when eth_getTransactionCount has not exposed them yet.
export function nextAvailableNonce(nodeNonce, pending) {
  return Math.max(
    nodeNonce,
    ...[...pending.values()].map((tx) => tx.nonce + 1)
  );
}

// Inclusion lags the send acknowledgement: live captures acknowledged by
// boundary+663ms and +793ms landed at +800ms and +1000ms. Budget a half
// block of jitter on top of predicted receipt; this remains a heuristic,
// not an inclusion guarantee.
const INCLUSION_SLACK_MS = 100;
let lastCaptureSendMs = null;
// Never send before the window opens: inclusion can follow the send
// acknowledgement almost immediately, so a pre-window send can land in the
// previous second and revert. Send only on a ready head whose predicted
// receipt still leaves jitter room before the last valid block.
export function captureAction(head, boundary, sendDelayMs) {
  const phase = captureState(head, boundary, 200);
  if (phase !== "ready") return phase;
  if (head.timestampMs == null) return "ready";
  const rpcMs = Number(head.rpcMs ?? 0);
  if (!Number.isFinite(rpcMs) || rpcMs < 0) return "invalid";
  const sendMs = sendDelayMs ?? lastCaptureSendMs ?? rpcMs;
  if (!Number.isFinite(sendMs) || sendMs < 0) return "invalid";
  const receipt = Number(head.timestampMs) + rpcMs + sendMs;
  if (receipt + INCLUSION_SLACK_MS >= boundary * 1000 + 800) return "missed";
  return "ready";
}

export async function broadcastTransaction({
  c,
  id,
  action,
  boundary,
  nonce,
  raw,
  blockTimeMs,
  rpc,
  pending,
  log,
  sendDelayMs,
}) {
  const key = `${c.address}:${id}:${action}:${boundary ?? ""}`;
  // Caller holds the wallet critical section across this check and send. A
  // paused maintenance pass must not reuse its old block snapshot for a retry.
  let latest;
  if (boundary) {
    latest = await rpc("eth_getBlockByNumber", ["latest", false]);
    const action =
      blockTimeMs === 200
        ? captureAction(latest, boundary, sendDelayMs)
        : captureState(latest, boundary, blockTimeMs);
    if (action !== "ready") {
      const tracked = pending.get(key);
      if (tracked && [...pending.values()].some((tx) => tx.nonce > nonce)) {
        // Do not abandon a missing lower nonce while accepted higher nonces
        // depend on it. Pause new work until receipt/nonce reconciliation or
        // manual wallet recovery resolves that queue; never retry it late.
        tracked.uncertain = true;
        if (!tracked.expired) {
          tracked.expired = true;
          log("nonce_gap", {
            contract: c.name,
            round: id,
            nonce,
            hash: tracked.hash,
          });
        }
      } else pending.delete(key);
      log("missed_boundary", { contract: c.name, round: id, boundary });
      return false;
    }
  }
  const hash = ethers.utils.keccak256(raw);
  const tx = {
    hash,
    raw,
    c,
    id,
    action,
    nonce,
    boundary,
    absentBlocks: 0,
    uncertain: false,
  };
  // Record before submitting: a transport timeout may still mean accepted.
  pending.set(key, tx);
  const started = Date.now();
  try {
    await rpc("eth_sendRawTransaction", [raw]);
  } catch (error) {
    if (
      error.rejected &&
      ![...pending.values()].some((entry) => entry.nonce > nonce)
    )
      pending.delete(key);
    else {
      tx.uncertain = true;
      if (error.rejected)
        log("nonce_gap", { contract: c.name, round: id, nonce, hash });
    }
    log(error.rejected ? "broadcast_rejected" : "broadcast_uncertain", {
      contract: c.name,
      round: id,
      action,
      hash,
      rpcCode: error.rpcCode,
    });
    return false;
  }
  if (boundary) lastCaptureSendMs = Date.now() - started;
  log("submitted", {
    contract: c.name,
    round: id,
    action,
    hash,
    ...(boundary
      ? {
          boundary,
          headTimestamp: Number(latest.timestamp),
          headTimestampMs:
            latest.timestampMs == null ? null : Number(latest.timestampMs),
          headRpcMs: latest.rpcMs,
        }
      : {}),
    broadcastMs: Date.now() - started,
  });
  return true;
}

// A native capture group shares one freshly fetched head and one HTTP batch.
// Batch members are independent transactions, not an atomic onchain operation.
export async function broadcastCaptureGroup({
  prepared,
  boundary,
  head,
  rpcBatch,
  pending,
  log,
  sendDelayMs,
}) {
  // Reject a head whose predicted receipt cannot land inside the boundary
  // second. This estimate is not an inclusion guarantee.
  const action = captureAction(head, boundary, sendDelayMs);
  if (action !== "ready") {
    for (const { c, id } of prepared)
      log("missed_boundary", {
        contract: c.name,
        round: id,
        boundary,
        reason: action === "missed" ? "insufficient_margin" : action,
      });
    return false;
  }
  if (prepared.length === 0 || prepared.length > 32) return false;
  if ([...pending.values()].some((tx) => tx.uncertain)) return false;
  const entries = prepared.map(({ c, id, raw, nonce }) => {
    const key = `${c.address}:${id}:captureBoundary:${boundary}`;
    const tx = {
      c,
      id,
      raw,
      nonce,
      boundary,
      action: "captureBoundary",
      hash: ethers.utils.keccak256(raw),
      absentBlocks: 0,
      uncertain: false,
    };
    return { key, tx };
  });
  // Register the entire nonce range before the request can reach the provider.
  // Partial acceptance must never make a lower nonce available for fresh work.
  for (const { key, tx } of entries) pending.set(key, tx);
  const started = Date.now();
  let replies;
  try {
    replies = await rpcBatch(
      entries.map(({ tx }) => ({
        method: "eth_sendRawTransaction",
        params: [tx.raw],
      }))
    );
    lastCaptureSendMs = Date.now() - started;
    if (!Array.isArray(replies) || replies.length !== entries.length)
      throw new Error("Incomplete capture batch");
    for (const [index, reply] of replies.entries())
      if (
        !reply.error &&
        reply.result?.toLowerCase() !== entries[index].tx.hash.toLowerCase()
      )
        throw new Error("Uncertain capture hash");
  } catch {
    replies = entries.map(() => ({
      error: new Error("Uncertain capture batch"),
    }));
  }
  const failed = replies.some((reply) => reply.error);
  for (const [index, { tx }] of entries.entries()) {
    const error = replies[index].error;
    // Even an acknowledged higher nonce can depend on an unaccepted lower
    // nonce. Reconcile the whole group before any fresh wallet work.
    if (failed) tx.uncertain = true;
    if (error) {
      log(error.rejected ? "broadcast_rejected" : "broadcast_uncertain", {
        contract: tx.c.name,
        round: tx.id,
        action: tx.action,
        hash: tx.hash,
        rpcCode: error.rpcCode,
      });
    } else {
      log("submitted", {
        contract: tx.c.name,
        round: tx.id,
        action: tx.action,
        hash: tx.hash,
        boundary,
        headTimestamp: Number(head.timestamp),
        headTimestampMs:
          head.timestampMs == null ? null : Number(head.timestampMs),
        headRpcMs: head.rpcMs,
        broadcastMs: Date.now() - started,
        captureBatchSize: entries.length,
      });
    }
  }
  return !failed;
}

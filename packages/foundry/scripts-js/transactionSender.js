import { ethers } from "ethers";

// Providers can lag their own send acknowledgement. Locally unresolved nonces
// remain reserved even when eth_getTransactionCount has not exposed them yet.
export function nextAvailableNonce(nodeNonce, pending) {
  return Math.max(
    nodeNonce,
    ...[...pending.values()].map((tx) => tx.nonce + 1)
  );
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
}) {
  const key = `${c.address}:${id}:${action}:${boundary ?? ""}`;
  // Caller holds the wallet critical section across this check and send. A
  // paused maintenance pass must not reuse its old block snapshot for a retry.
  if (boundary) {
    const latest = await rpc("eth_getBlockByNumber", ["latest", false]);
    const now = Number(latest.timestamp);
    if (blockTimeMs === 200 ? now !== boundary : now + 2 !== boundary) {
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
  log("submitted", { contract: c.name, round: id, action, hash });
  return true;
}

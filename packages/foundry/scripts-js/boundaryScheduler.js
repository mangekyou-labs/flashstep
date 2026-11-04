import { captureState } from "./captureWindow.js";
import { nextAvailableNonce } from "./transactionSender.js";

// Native sub-second blocks still expose whole-second EVM timestamps. Prepare
// ahead, then target inclusion in the exact second; never move a boundary.
export function createBoundaryScheduler({
  contracts,
  rpc,
  call,
  wallet,
  chainId,
  gasLimit,
  pending,
  broadcast,
  log,
  sleep,
  isRunning,
  poll,
  checkCaptureReceipts = async () => {},
}) {
  let head;
  let observedAt;
  const attempted = new Map();
  const key = (c, id, boundary) => `${c.address}:${id}:${boundary}`;
  function targets() {
    for (const [id, boundary] of attempted)
      if (boundary < Number(head.timestamp) - 120) {
        const [address, roundId] = id.split(":");
        if (
          !contracts.some((c) => c.address === address && c.rounds.has(roundId))
        )
          attempted.delete(id);
      }
    const work = [];
    for (const c of contracts) {
      for (const id of c.rounds) {
        const r = c.roundData.get(id);
        if (!r || r.result !== 0) continue;
        const boundaries = [[r.windowEnd.toNumber(), r.endBlock]];
        if (c.name === "UpDownRounds")
          boundaries.push([r.cutoff.toNumber(), r.startBlock]);
        for (const [boundary, captured] of boundaries) {
          if (!captured.isZero() || attempted.has(key(c, id, boundary)))
            continue;
          if (boundary < Number(head.timestamp)) {
            attempted.set(key(c, id, boundary), boundary);
            log("missed_boundary", { contract: c.name, round: id, boundary });
          } else work.push({ c, id, boundary });
        }
      }
    }
    return work.sort((a, b) => a.boundary - b.boundary);
  }
  return {
    observe(block) {
      head = block;
      observedAt = Date.now();
    },
    async service() {
      if (!head || !isRunning()) return;
      // Resolve ambiguous acceptance before putting a higher nonce behind it.
      if ([...pending.values()].some((tx) => tx.uncertain)) return;
      const first = targets()[0];
      if (!first) return;
      // This estimate only preempts background work. Submission always uses a
      // fresh chain timestamp, never the host clock or an extrapolated price.
      const estimated =
        Number(head.timestamp) + (Date.now() - observedAt) / 1000;
      if (estimated < first.boundary - 3) return;
      await checkCaptureReceipts();
      if (!isRunning()) return;
      // A restart may have cached one contract before background discovery
      // reaches the other. Load both schedules and all known uncached Rounds
      // before holding maintenance until the earliest shared boundary.
      for (const c of contracts) {
        const [current] = await call(c, "currentRound");
        if (!current.isZero()) c.rounds.add(current.toString());
        for (const id of c.rounds) {
          if (!c.roundData.has(id)) {
            const [r] = await call(c, "round", [id]);
            c.roundData.set(id, r);
          }
        }
      }
      await rpc("eth_getBlockByNumber", ["latest", false]);
      const work = targets();
      if (!work.length || Number(head.timestamp) < work[0].boundary - 3) return;
      const boundary = work[0].boundary;
      const group = work.filter((w) => w.boundary === boundary);
      const gasPrice = await rpc("eth_gasPrice", []);
      const mined = Number(
        await rpc("eth_getTransactionCount", [wallet.address, "latest"])
      );
      let nonce = Number(
        await rpc("eth_getTransactionCount", [wallet.address, "pending"])
      );
      // A restarted process must leave an unknown wallet queue alone.
      if (nonce > mined && pending.size === 0) return;
      nonce = nextAvailableNonce(nonce, pending);
      const prepared = [];
      for (const { c, id } of group) {
        const [r] = await call(c, "round", [id]);
        const captured =
          c.name === "UpDownRounds" && boundary === r.cutoff.toNumber()
            ? r.startBlock
            : r.endBlock;
        if (r.result !== 0 || !captured.isZero()) continue;
        const raw = await wallet.signTransaction({
          to: c.address,
          data: c.iface.encodeFunctionData("captureBoundary", [id]),
          nonce,
          chainId,
          gasLimit,
          gasPrice,
        });
        prepared.push({ c, id, raw, nonce: nonce++ });
      }
      if (!prepared.length) return;
      log("capture_prepared", { boundary, count: prepared.length });
      // Hold maintenance here: log scans, old settlements and receipt polling
      // must not consume the one-second inclusion window.
      while (isRunning()) {
        await rpc("eth_getBlockByNumber", ["latest", false]);
        const state = captureState(head, boundary, 200);
        if (state === "expired" || state === "invalid") {
          for (const { c, id } of prepared) {
            attempted.set(key(c, id, boundary), boundary);
            log("missed_boundary", { contract: c.name, round: id, boundary });
          }
          return;
        }
        if (state === "ready") {
          for (const { c, id, raw, nonce: txNonce } of prepared) {
            if (!isRunning()) return;
            attempted.set(key(c, id, boundary), boundary);
            // Keep broadcasts ordered so a definite rejection cannot leave a
            // higher-nonce transaction stranded behind an unsent transaction.
            if (
              !(await broadcast(
                c,
                id,
                "captureBoundary",
                boundary,
                txNonce,
                raw
              ))
            )
              return;
          }
          return;
        }
        await sleep(poll);
      }
    },
  };
}

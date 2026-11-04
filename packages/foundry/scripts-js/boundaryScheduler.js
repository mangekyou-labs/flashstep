import {
  captureAction,
  nextAvailableNonce,
} from "./transactionSender.js";

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
  callMany = (calls) =>
    Promise.all(calls.map(({ c, method, args }) => call(c, method, args))),
  rpcBatch = (calls) =>
    Promise.all(
      calls.map(async ({ method, params }) => ({
        result: await rpc(method, params),
      }))
    ),
  broadcastGroup,
  prepareAccount,
}) {
  let head;
  let observedAt;
  let warmedBoundary = null;
  let warmedHeadMs = null;
  const attempted = new Map();
  // Hydration batches cost seconds on a measured-latency provider. Finish
  // them well before the window so the hold loop can send on the first ready
  // head instead of discovering a late one after preparation.
  const PREPARE_LEAD_SECONDS = 12;
  const FINAL_LEAD_SECONDS = 2;
  const estimatedNow = () =>
    head.timestampMs != null
      ? Number(head.timestampMs) / 1000 + (Date.now() - observedAt) / 1000
      : Number(head.timestamp) + (Date.now() - observedAt) / 1000;
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
      if (estimatedNow() < first.boundary - PREPARE_LEAD_SECONDS) return;
      // Skip re-warming only when the caller's own block polling has moved
      // the head since preparation; otherwise fall through and advance it.
      const headMs = Number(head.timestampMs ?? Number(head.timestamp) * 1000);
      if (
        warmedBoundary === first.boundary &&
        warmedHeadMs != null &&
        headMs > warmedHeadMs &&
        estimatedNow() < first.boundary - FINAL_LEAD_SECONDS
      )
        return;
      await checkCaptureReceipts();
      if (!isRunning()) return;
      // A restart may have cached one contract before background discovery
      // reaches the other. Load both schedules and all known uncached Rounds
      // before holding maintenance until the earliest shared boundary.
      const accountSnapshot = prepareAccount ? await prepareAccount() : null;
      const currents =
        accountSnapshot?.currents ??
        (await callMany(contracts.map((c) => ({ c, method: "currentRound" }))));
      const missing = [];
      contracts.forEach((c, index) => {
        const [current] = currents[index];
        if (!current.isZero()) c.rounds.add(current.toString());
        for (const id of c.rounds)
          if (!c.roundData.has(id))
            missing.push({ c, method: "round", args: [id] });
      });
      const hydrated = await callMany(missing);
      missing.forEach(({ c, args: [id] }, index) =>
        c.roundData.set(id, hydrated[index][0])
      );
      await rpc("eth_getBlockByNumber", ["latest", false]);
      const work = targets();
      if (!work.length) return;
      warmedBoundary = work[0].boundary;
      warmedHeadMs = Number(head.timestampMs ?? Number(head.timestamp) * 1000);
      // Preparation is done; leave background work alone until the final
      // account/sign/hold stage. Signing still happens there, so intervening
      // settlements cannot strand this group behind a stale nonce.
      if (estimatedNow() < work[0].boundary - FINAL_LEAD_SECONDS) return;
      const boundary = work[0].boundary;
      const group = work.filter((w) => w.boundary === boundary);
      const account = accountSnapshot
        ? [
            { result: accountSnapshot.gasPrice },
            { result: accountSnapshot.mined },
            { result: accountSnapshot.nonce },
          ]
        : await rpcBatch([
            { method: "eth_gasPrice", params: [] },
            {
              method: "eth_getTransactionCount",
              params: [wallet.address, "latest"],
            },
            {
              method: "eth_getTransactionCount",
              params: [wallet.address, "pending"],
            },
          ]);
      for (const entry of account) if (entry.error) throw entry.error;
      const gasPrice = account[0].result;
      const mined = Number(account[1].result);
      let nonce = Number(account[2].result);
      // A restarted process must leave an unknown wallet queue alone.
      if (nonce > mined && pending.size === 0) return;
      nonce = nextAvailableNonce(nonce, pending);
      const prepared = [];
      const fresh = await callMany(
        group.map(({ c, id }) => ({ c, method: "round", args: [id] }))
      );
      for (const [index, { c, id }] of group.entries()) {
        const [r] = fresh[index];
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
        const action = captureAction(head, boundary);
        if (action === "expired" || action === "invalid" || action === "missed") {
          for (const { c, id } of prepared) {
            attempted.set(key(c, id, boundary), boundary);
            log("missed_boundary", {
              contract: c.name,
              round: id,
              boundary,
              ...(action === "missed"
                ? { reason: "insufficient_margin" }
                : {}),
            });
          }
          return;
        }
        if (action === "ready") {
          if (broadcastGroup) {
            for (const { c, id } of prepared)
              attempted.set(key(c, id, boundary), boundary);
            // No intervening read: this is the fresh head that opened the gate.
            await broadcastGroup(prepared, boundary, head);
            return;
          }
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

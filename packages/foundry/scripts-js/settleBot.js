import { readFile } from "node:fs/promises";
import { ethers } from "ethers";
import { createBoundaryScheduler } from "./boundaryScheduler.js";
import {
  broadcastTransaction,
  broadcastCaptureGroup,
  nextAvailableNonce,
} from "./transactionSender.js";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const log = (event, fields = {}) =>
  console.log(JSON.stringify({ event, ...fields }));
let running = true;
for (const signal of ["SIGINT", "SIGTERM"])
  process.on(signal, () => {
    running = false;
  });

function integer(name, fallback, min = 0) {
  const value = Number(process.env[name] ?? fallback);
  if (!Number.isSafeInteger(value) || value < min)
    throw new Error(`Invalid ${name}`);
  return value;
}

async function main() {
  const url = process.env.SETTLE_RPC_URL;
  if (!url || !["http:", "https:"].includes(new URL(url).protocol))
    throw new Error("Invalid SETTLE_RPC_URL");
  let wallet;
  try {
    wallet = new ethers.Wallet(process.env.SETTLE_PRIVATE_KEY);
  } catch {
    throw new Error("Invalid SETTLE_PRIVATE_KEY");
  }
  const interval = integer("SETTLE_REQUEST_INTERVAL_MS", 10, 1);
  const poll = integer("SETTLE_POLL_MS", 50, 1);
  const fromBlock = integer("SETTLE_FROM_BLOCK", 0);
  const logRange = integer("SETTLE_LOG_BLOCK_RANGE", 2000, 1);
  const gasLimit = integer("SETTLE_GAS_LIMIT", 1500000, 21000);
  const contracts = [];
  for (const [name, env] of [
    ["UpDownRounds", "SETTLE_UPDOWN_ADDRESS"],
    ["ThresholdPots", "SETTLE_THRESHOLD_ADDRESS"],
  ]) {
    const address = process.env[env];
    if (
      !ethers.utils.isAddress(address) ||
      address === ethers.constants.AddressZero
    )
      throw new Error(`Invalid ${env}`);
    const { abi } = JSON.parse(
      await readFile(
        new URL(`../out/${name}.sol/${name}.json`, import.meta.url)
      )
    );
    contracts.push({
      name,
      address,
      iface: new ethers.utils.Interface(abi),
      rounds: new Set(),
      roundData: new Map(),
      history: new Set(),
      cursor: fromBlock,
      recentCursor: undefined,
    });
  }
  let nextRequest = 0;
  let requestId = 0;
  let boundaryScheduler;
  let servicingBoundary = false;
  async function rpc(method, params) {
    // Check deadlines between every background request, rather than waiting
    // for a potentially multi-second discovery/settlement pass to complete.
    if (boundaryScheduler && !servicingBoundary) {
      servicingBoundary = true;
      try {
        await boundaryScheduler.service();
      } finally {
        servicingBoundary = false;
      }
    }
    const batch = Array.isArray(method);
    const calls = batch ? method : [{ method, params }];
    if (calls.length === 0) return [];
    if (calls.length > 32) throw new Error("RPC batch exceeds 32 calls");
    const requests = calls.map((call) => ({
      ...call,
      jsonrpc: "2.0",
      id: ++requestId,
    }));
    await sleep(Math.max(0, nextRequest - Date.now()));
    let response;
    const requestStarted = Date.now();
    try {
      response = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(batch ? requests : requests[0]),
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      nextRequest = Date.now() + interval;
      throw new Error(`RPC transport failure (${method})`);
    }
    nextRequest = Date.now() + interval;
    if (!response.ok)
      throw new Error(`RPC HTTP ${response.status} (${method})`);
    const body = await response.json();
    // A batch is one HTTP round trip but still consumes one allowance per call.
    nextRequest = Date.now() + interval * calls.length;
    const responses = batch ? body : [body];
    if (!Array.isArray(responses) || responses.length !== requests.length)
      throw new Error("Incomplete RPC response");
    const byId = new Map(responses.map((reply) => [reply.id, reply]));
    if (byId.size !== requests.length || requests.some((r) => !byId.has(r.id)))
      throw new Error("Invalid RPC response ids");
    const entries = requests.map((request) => {
      const reply = byId.get(request.id);
      if (reply.error) {
        const error = new Error(`RPC rejected ${request.method}`);
        error.rpcData = reply.error.data;
        error.rpcCode = reply.error.code;
        error.rejected = !/already known|nonce too low/i.test(
          reply.error.message ?? ""
        );
        return { error };
      }
      if (!("result" in reply)) throw new Error("Missing RPC result");
      if (
        request.method === "eth_getBlockByNumber" &&
        request.params[0] === "latest" &&
        reply.result
      ) {
        reply.result.rpcMs = Date.now() - requestStarted;
        boundaryScheduler?.observe(reply.result);
      }
      return { result: reply.result };
    });
    if (batch) return entries;
    if (entries[0].error) throw entries[0].error;
    return entries[0].result;
  }
  const rpcBatch = (calls) => rpc(calls);

  const hex = ethers.utils.hexValue;
  async function call(c, method, args = []) {
    const data = c.iface.encodeFunctionData(method, args);
    const result = c.iface.decodeFunctionResult(
      method,
      await rpc("eth_call", [{ to: c.address, data }, "latest"])
    );
    if (method === "round" && c.rounds.has(String(args[0])))
      c.roundData.set(String(args[0]), result[0]);
    return result;
  }
  async function callMany(calls) {
    const decoded = [];
    for (let offset = 0; offset < calls.length; offset += 32) {
      const chunk = calls.slice(offset, offset + 32);
      const entries = await rpcBatch(
        chunk.map(({ c, method, args = [] }) => ({
          method: "eth_call",
          params: [
            { to: c.address, data: c.iface.encodeFunctionData(method, args) },
            "latest",
          ],
        }))
      );
      entries.forEach((entry, index) => {
        if (entry.error) throw entry.error;
        const { c, method, args = [] } = chunk[index];
        const result = c.iface.decodeFunctionResult(method, entry.result);
        if (method === "round" && c.rounds.has(String(args[0])))
          c.roundData.set(String(args[0]), result[0]);
        decoded.push(result);
      });
    }
    return decoded;
  }
  const startup = await rpcBatch([
    { method: "eth_chainId", params: [] },
    ...contracts.map((c) => ({
      method: "eth_getCode",
      params: [c.address, "latest"],
    })),
    { method: "eth_getBlockByNumber", params: ["latest", false] },
  ]);
  for (const entry of startup) if (entry.error) throw entry.error;
  const chainId = Number(startup[0].result);
  contracts.forEach((c, index) => {
    if (startup[index + 1].result === "0x")
      throw new Error(`No ${c.name} contract at configured address`);
  });
  const pending = new Map();
  const initialHead = startup.at(-1).result;
  const parent = await rpc("eth_getBlockByNumber", [
    hex(Math.max(0, Number(initialHead.number) - 1)),
    false,
  ]);
  const observedStep = Number(initialHead.timestamp) - Number(parent.timestamp);
  const blockTimeMs = integer(
    "SETTLE_BLOCK_TIME_MS",
    observedStep < 2 ? 200 : 2000,
    1
  );
  if (![200, 2000].includes(blockTimeMs))
    throw new Error("Invalid SETTLE_BLOCK_TIME_MS");
  if (blockTimeMs === 200) {
    boundaryScheduler = createBoundaryScheduler({
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
      isRunning: () => running,
      poll,
      checkCaptureReceipts,
      callMany,
      rpcBatch,
      prepareAccount: async () => {
        const entries = await rpcBatch([
          ...contracts.map((c) => ({
            method: "eth_call",
            params: [
              {
                to: c.address,
                data: c.iface.encodeFunctionData("currentRound", []),
              },
              "latest",
            ],
          })),
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
        for (const entry of entries) if (entry.error) throw entry.error;
        return {
          currents: contracts.map((c, index) =>
            c.iface.decodeFunctionResult("currentRound", entries[index].result)
          ),
          gasPrice: entries[contracts.length].result,
          mined: Number(entries[contracts.length + 1].result),
          nonce: Number(entries[contracts.length + 2].result),
        };
      },
      broadcastGroup: async (prepared, boundary, head) => {
        if (!running) return false;
        return broadcastCaptureGroup({
          prepared,
          boundary,
          head,
          rpcBatch,
          pending,
          log,
        });
      },
    });
    boundaryScheduler.observe(initialHead);
  }
  let lastBlock;
  log("ready", {
    sender: wallet.address,
    chainId,
    requestIntervalMs: interval,
    pollMs: poll,
    blockTimeMs,
    nativeTimestampMs: initialHead.timestampMs != null,
  });

  // Prime restart recovery before receipt/history maintenance. The initial
  // lookback is conservative, then verified by elapsed chain time.
  if (blockTimeMs === 200) {
    const height = Number(initialHead.number);
    let distance = 512;
    let recentStart = Math.max(fromBlock, height - distance);
    while (recentStart > fromBlock) {
      const older = await rpc("eth_getBlockByNumber", [
        hex(recentStart),
        false,
      ]);
      if (Number(older.timestamp) <= Number(initialHead.timestamp) - 64) break;
      distance *= 2;
      recentStart = Math.max(fromBlock, height - distance);
    }
    const queries = contracts.map((c) => ({
      method: "eth_call",
      params: [
        { to: c.address, data: c.iface.encodeFunctionData("currentRound", []) },
        "latest",
      ],
    }));
    const logQueries = [];
    for (const c of contracts)
      for (let cursor = recentStart; cursor <= height; cursor += logRange)
        logQueries.push({
          c,
          end: Math.min(height, cursor + logRange - 1),
          query: {
            method: "eth_getLogs",
            params: [
              {
                address: c.address,
                fromBlock: hex(cursor),
                toBlock: hex(Math.min(height, cursor + logRange - 1)),
                topics: [c.iface.getEventTopic("RoundSeeded")],
              },
            ],
          },
        });
    // Respect both provider log-range limits and the bounded HTTP batch size.
    for (
      let offset = 0;
      offset < logQueries.length + queries.length;
      offset += 32
    ) {
      const all = [...queries, ...logQueries.map((entry) => entry.query)];
      const replies = await rpcBatch(all.slice(offset, offset + 32));
      replies.forEach((entry, i) => {
        if (entry.error) throw entry.error;
        const index = offset + i;
        if (index < contracts.length) {
          const c = contracts[index];
          const [current] = c.iface.decodeFunctionResult(
            "currentRound",
            entry.result
          );
          if (!current.isZero()) c.rounds.add(current.toString());
        } else {
          const { c, end } = logQueries[index - contracts.length];
          for (const event of entry.result) {
            const r = c.iface.parseLog(event).args;
            if (r.windowEnd.toNumber() >= Number(initialHead.timestamp))
              c.rounds.add(r.roundId.toString());
            else c.history.add(r.roundId.toString());
          }
          c.recentCursor = end + 1;
        }
      });
    }
    await callMany(
      contracts.flatMap((c) =>
        [...c.rounds].map((id) => ({ c, method: "round", args: [id] }))
      )
    );
  }

  async function send(c, id, action, gasPrice, boundary) {
    if (!running || [...pending.values()].some((tx) => tx.uncertain)) return;
    const key = `${c.address}:${id}:${action}:${boundary ?? ""}`;
    if (pending.has(key)) return;
    // A fresh result check avoids spending gas when another caller already settled.
    const [round] = await call(c, "round", [id]);
    if (round.result !== 0) {
      c.rounds.delete(id);
      c.roundData.delete(id);
      return;
    }
    if (boundary) {
      if (
        !(
          boundary === round.cutoff.toNumber() && c.name === "UpDownRounds"
            ? round.startBlock
            : round.endBlock
        ).isZero()
      )
        return;
      const latest = await rpc("eth_getBlockByNumber", ["latest", false]);
      if (Number(latest.timestamp) + 2 !== boundary) {
        log("missed_boundary", { contract: c.name, round: id, boundary });
        return;
      }
    }
    const data = c.iface.encodeFunctionData(action, [id]);
    if (action === "settle") {
      // Eligibility can be virtual (phase Refunded): actually finalize it onchain.
      try {
        await rpc("eth_call", [
          { from: wallet.address, to: c.address, data },
          "latest",
        ]);
      } catch (error) {
        if (!error.rpcData && !error.rejected) throw error;
        return; // Too early, missing Reading, or another caller won the race; retry next block.
      }
    }
    // Nonce allocation through broadcast is one critical section: a capture
    // must not preempt an already-signed settlement and reuse its nonce.
    const previous = servicingBoundary;
    servicingBoundary = true;
    try {
      if (!running || [...pending.values()].some((tx) => tx.uncertain)) return;
      const nonce = nextAvailableNonce(
        Number(
          await rpc("eth_getTransactionCount", [wallet.address, "pending"])
        ),
        pending
      );
      if (!running) return;
      const raw = await wallet.signTransaction({
        to: c.address,
        data,
        nonce,
        chainId,
        gasLimit,
        gasPrice,
      });
      await broadcast(c, id, action, boundary, nonce, raw);
    } finally {
      servicingBoundary = previous;
    }
  }

  async function broadcast(c, id, action, boundary, nonce, raw) {
    if (!running) return false;
    const previous = servicingBoundary;
    servicingBoundary = true;
    try {
      return await broadcastTransaction({
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
      });
    } finally {
      servicingBoundary = previous;
    }
  }

  async function checkCaptureReceipts() {
    for (const [key, tx] of pending) {
      if (tx.action !== "captureBoundary") continue;
      const receipt = await rpc("eth_getTransactionReceipt", [tx.hash]);
      if (receipt) {
        await recordReceipt(key, tx, receipt);
        if (!running) return;
      }
    }
  }

  async function recordReceipt(key, tx, receipt) {
    if (pending.get(key) !== tx) return;
    const reverted = Number(receipt.status) !== 1;
    log(reverted ? "reverted" : "confirmed", {
      contract: tx.c.name,
      round: tx.id,
      action: tx.action,
      hash: tx.hash,
    });
    pending.delete(key);
    if (reverted && tx.action === "captureBoundary") {
      // A successful send acknowledgement says nothing about inclusion timing.
      // Stop new wallet work immediately, including any preempted outer pass.
      running = false;
      process.exitCode = 1;
      let reason = "Unknown";
      try {
        await rpc("eth_call", [
          {
            from: wallet.address,
            to: tx.c.address,
            data: tx.c.iface.encodeFunctionData(tx.action, [tx.id]),
          },
          receipt.blockNumber,
        ]);
      } catch (error) {
        try {
          reason = tx.c.iface.parseError(error.rpcData).name;
        } catch {}
      }
      log("capture_failed", {
        contract: tx.c.name,
        round: tx.id,
        hash: tx.hash,
        boundary: tx.boundary,
        includedBlock: Number(receipt.blockNumber),
        includedTimestampMs:
          receipt.blockTimestampMs == null
            ? null
            : Number(receipt.blockTimestampMs),
        reason,
        stopped: true,
      });
    }
  }

  while (running) {
    try {
      const block = await rpc("eth_getBlockByNumber", ["latest", false]);
      if (!running) return;
      if (block.hash === lastBlock) {
        await sleep(poll);
        continue;
      }
      for (const [key, tx] of pending) {
        const receipt = await rpc("eth_getTransactionReceipt", [tx.hash]);
        if (receipt) {
          await recordReceipt(key, tx, receipt);
          if (!running) return;
        } else {
          const minedNonce = Number(
            await rpc("eth_getTransactionCount", [wallet.address, "latest"])
          );
          if (minedNonce > tx.nonce) {
            pending.delete(key);
            continue;
          }
          const transaction = await rpc("eth_getTransactionByHash", [tx.hash]);
          if (transaction) {
            tx.absentBlocks = 0;
            tx.uncertain = false;
            continue;
          }
          if (++tx.absentBlocks < 3) continue;
          // Reuse the same signed payload/hash and nonce after ambiguous transport
          // failures. Never rebroadcast an expired exact-boundary capture.
          await broadcast(
            tx.c,
            tx.id,
            tx.action,
            tx.boundary,
            tx.nonce,
            tx.raw
          );
        }
      }
      // Serialize this wallet; on restart leave pre-existing pending transactions time to land.
      const mined = Number(
        await rpc("eth_getTransactionCount", [wallet.address, "latest"])
      );
      const queued = Number(
        await rpc("eth_getTransactionCount", [wallet.address, "pending"])
      );
      if (queued > mined && pending.size === 0) {
        await sleep(poll);
        continue;
      }
      const now = Number(block.timestamp);
      const height = Number(block.number);
      const gasPrice = await rpc("eth_gasPrice", []);
      // Recover at least 64 seconds of events regardless of block cadence.
      // Exponential timestamp search also handles a node resuming after downtime.
      let recentStart = Math.max(fromBlock, height - 32);
      if (
        contracts.some(
          (c) => c.recentCursor === undefined || c.recentCursor < recentStart
        )
      ) {
        let distance = 32;
        while (recentStart > fromBlock) {
          const older = await rpc("eth_getBlockByNumber", [
            hex(recentStart),
            false,
          ]);
          if (Number(older.timestamp) <= now - 64) break;
          distance *= 2;
          recentStart = Math.max(fromBlock, height - distance);
        }
      }
      // Fresh schedule discovery takes precedence over replaying historical logs.
      for (const c of contracts) {
        const [current] = await call(c, "currentRound");
        if (!current.isZero()) c.rounds.add(current.toString());
      }
      for (const c of contracts) {
        const start = Math.max(recentStart, c.recentCursor ?? recentStart);
        for (let cursor = start; cursor <= height; cursor += logRange) {
          const end = Math.min(height, cursor + logRange - 1);
          const events = await rpc("eth_getLogs", [
            {
              address: c.address,
              fromBlock: hex(cursor),
              toBlock: hex(end),
              topics: [c.iface.getEventTopic("RoundSeeded")],
            },
          ]);
          for (const event of events) {
            const r = c.iface.parseLog(event).args;
            const id = r.roundId.toString();
            if (r.windowEnd.toNumber() >= now) c.rounds.add(id);
            else c.history.add(id);
          }
          c.recentCursor = end + 1;
        }
      }
      const settlements = [];
      for (const c of contracts) {
        for (const id of c.rounds) {
          const [r] = await call(c, "round", [id]);
          if (r.result !== 0) {
            c.rounds.delete(id);
            c.roundData.delete(id);
            continue;
          }
          const cutoff = r.cutoff.toNumber();
          const end = r.windowEnd.toNumber();
          // Legacy cadence submits one block ahead. Native captures use the
          // priority scheduler; neither substitutes a later Reading.
          const startDue =
            c.name === "UpDownRounds" &&
            r.startBlock.isZero() &&
            cutoff === now + 2;
          if (
            blockTimeMs === 2000 &&
            (startDue || (r.endBlock.isZero() && end === now + 2))
          )
            await send(
              c,
              id,
              "captureBoundary",
              gasPrice,
              startDue ? cutoff : end
            );
          if (end <= now) settlements.push([c, id]);
          if (end + 60 <= now) {
            c.rounds.delete(id);
            c.roundData.delete(id);
            c.history.add(id);
          }
        }
      }
      for (const [c, id] of settlements) await send(c, id, "settle", gasPrice);
      // A small rotating replay budget keeps restart recovery progressing without
      // reading every historical Round before submitting time-sensitive captures.
      for (const c of contracts) {
        if (c.cursor <= height) {
          const end = Math.min(height, c.cursor + logRange - 1);
          const events = await rpc("eth_getLogs", [
            {
              address: c.address,
              fromBlock: hex(c.cursor),
              toBlock: hex(end),
              topics: [c.iface.getEventTopic("RoundSeeded")],
            },
          ]);
          for (const event of events)
            c.history.add(c.iface.parseLog(event).args.roundId.toString());
          c.cursor = end + 1;
        }
        for (const id of [...c.history].slice(0, 4)) {
          c.history.delete(id);
          const [r] = await call(c, "round", [id]);
          if (r.result !== 0) continue;
          if (r.windowEnd.toNumber() > now) {
            c.rounds.add(id);
            continue;
          }
          await send(c, id, "settle", gasPrice);
          c.history.add(id);
        }
      }
      lastBlock = block.hash;
    } catch (error) {
      // Never print provider error bodies, request payloads, RPC URLs or wallet material.
      log("retry", {
        reason: error.message.startsWith("RPC ")
          ? error.message
          : "Operation failed",
      });
    }
    await sleep(poll);
  }
}

main().catch((error) => {
  console.error(
    error.message.startsWith("Invalid SETTLE_") ||
      error.message.startsWith("No ")
      ? error.message
      : "Settle bot could not start; check configuration and compiled artifacts"
  );
  process.exitCode = 1;
});

import { readFile } from "node:fs/promises";
import { ethers } from "ethers";

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
      history: new Set(),
      cursor: fromBlock,
      recentCursor: undefined,
    });
  }
  let nextRequest = 0;
  let requestId = 0;
  async function rpc(method, params) {
    await sleep(Math.max(0, nextRequest - Date.now()));
    nextRequest = Date.now() + interval;
    let response;
    try {
      response = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          jsonrpc: "2.0",
          id: ++requestId,
          method,
          params,
        }),
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
    nextRequest = Date.now() + interval;
    if (body.error) {
      const error = new Error(`RPC rejected ${method}`);
      error.rpcData = body.error.data;
      error.rpcCode = body.error.code;
      error.rejected = !/already known|nonce too low/i.test(
        body.error.message ?? ""
      );
      throw error;
    }
    return body.result;
  }
  const hex = ethers.utils.hexValue;
  async function call(c, method, args = []) {
    const data = c.iface.encodeFunctionData(method, args);
    return c.iface.decodeFunctionResult(
      method,
      await rpc("eth_call", [{ to: c.address, data }, "latest"])
    );
  }
  const chainId = Number(await rpc("eth_chainId", []));
  for (const c of contracts) {
    if ((await rpc("eth_getCode", [c.address, "latest"])) === "0x")
      throw new Error(`No ${c.name} contract at configured address`);
  }
  const pending = new Map();
  let lastBlock;
  log("ready", {
    sender: wallet.address,
    chainId,
    requestIntervalMs: interval,
    pollMs: poll,
  });

  async function send(c, id, action, gasPrice, boundary) {
    const key = `${c.address}:${id}:${action}:${boundary ?? ""}`;
    if (pending.has(key)) return;
    // A fresh result check avoids spending gas when another caller already settled.
    const [round] = await call(c, "round", [id]);
    if (round.result !== 0) {
      c.rounds.delete(id);
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
    const nonce = Number(
      await rpc("eth_getTransactionCount", [wallet.address, "pending"])
    );
    const raw = await wallet.signTransaction({
      to: c.address,
      data,
      nonce,
      chainId,
      gasLimit,
      gasPrice,
    });
    // Track the deterministic hash before broadcast: a timeout may still mean accepted.
    const hash = ethers.utils.keccak256(raw);
    pending.set(key, {
      hash,
      raw,
      c,
      id,
      action,
      nonce,
      boundary,
      absentBlocks: 0,
    });
    try {
      await rpc("eth_sendRawTransaction", [raw]);
    } catch (error) {
      if (error.rejected) pending.delete(key);
      log(error.rejected ? "broadcast_rejected" : "broadcast_uncertain", {
        contract: c.name,
        round: id,
        action,
        hash,
        rpcCode: error.rpcCode,
      });
      return;
    }
    log("submitted", { contract: c.name, round: id, action, hash });
  }

  while (running) {
    try {
      const block = await rpc("eth_getBlockByNumber", ["latest", false]);
      if (block.hash === lastBlock) {
        await sleep(poll);
        continue;
      }
      for (const [key, tx] of pending) {
        const receipt = await rpc("eth_getTransactionReceipt", [tx.hash]);
        if (receipt) {
          log(Number(receipt.status) === 1 ? "confirmed" : "reverted", {
            contract: tx.c.name,
            round: tx.id,
            action: tx.action,
            hash: tx.hash,
          });
          pending.delete(key);
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
            continue;
          }
          if (++tx.absentBlocks < 3) continue;
          // Reuse the same signed payload/hash and nonce after ambiguous transport
          // failures. Never rebroadcast an expired exact-boundary capture.
          if (tx.boundary && Number(block.timestamp) + 2 !== tx.boundary) {
            pending.delete(key);
            log("capture_not_found", {
              contract: tx.c.name,
              round: tx.id,
              hash: tx.hash,
            });
          } else {
            try {
              await rpc("eth_sendRawTransaction", [tx.raw]);
            } catch (error) {
              if (error.rejected) pending.delete(key);
            }
            tx.absentBlocks = 0;
          }
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
      // Fresh schedule discovery takes precedence over replaying historical logs.
      for (const c of contracts) {
        const [current] = await call(c, "currentRound");
        if (!current.isZero()) c.rounds.add(current.toString());
      }
      for (const c of contracts) {
        // At most 30s trading + 30s Window: the last 32 two-second blocks
        // include every still-capturable seeded Round, even on a fresh restart.
        // Replay these before captures; old escrow recovery has its own cursor.
        const start = Math.max(fromBlock, height - 32, c.recentCursor ?? 0);
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
            continue;
          }
          const cutoff = r.cutoff.toNumber();
          const end = r.windowEnd.toNumber();
          // Contracts pin exact 2-second boundaries. Submit one block ahead;
          // no latest-price substitution if inclusion misses that block.
          const startDue =
            c.name === "UpDownRounds" &&
            r.startBlock.isZero() &&
            cutoff === now + 2;
          if (startDue || (r.endBlock.isZero() && end === now + 2))
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

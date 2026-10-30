"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { AbiEvent, Address, Hash, PublicClient, erc20Abi, getAbiItem, zeroAddress } from "viem";
import { usePublicClient } from "wagmi";
import { Market, Payer, marketAddress } from "~~/config/payers";
import { roundsAbi } from "~~/utils/rounds/abi";
import { thresholdAbi } from "~~/utils/rounds/thresholdAbi";

/** Both contracts number their phases the same way; 3 and 4 are the two end states. */
const PHASE_SETTLED = 3;
const PHASE_REFUNDED = 4;
export function isFinished(phase: number): boolean {
  return phase === PHASE_SETTLED || phase === PHASE_REFUNDED;
}

/** Link to a transaction on the payer's block explorer, or undefined when the chain has none. */
export function explorerTxUrl(explorerUrl: string, hash: Hash): string | undefined {
  return explorerUrl ? `${explorerUrl}/tx/${hash}` : undefined;
}

/** Page URL that opens one Round. Round ids and brand come from known values, never raw input. */
export function roundUrl(origin: string, payer: Payer, market: Market, roundId: bigint | undefined): string {
  const url = new URL("/rounds", origin);
  url.searchParams.set("brand", payer.ticker);
  if (market === "threshold") url.searchParams.set("market", "threshold");
  if (roundId) url.searchParams.set("round", roundId.toString());
  return url.toString();
}

export function shareLinks(url: string, text: string) {
  return {
    x: `https://x.com/intent/post?${new URLSearchParams({ text, url })}`,
    telegram: `https://t.me/share/url?${new URLSearchParams({ url, text })}`,
  };
}

/** The URL of this page's origin, available only after mount so server and client markup agree. */
export function useOrigin() {
  const [origin, setOrigin] = useState("");
  useEffect(() => setOrigin(window.location.origin), []);
  return origin;
}

const marketAbi = { updown: roundsAbi, threshold: thresholdAbi } as const;
function eventOf(market: Market, name: "Settled" | "Refunded"): AbiEvent {
  return getAbiItem({ abi: marketAbi[market] as typeof roundsAbi, name }) as AbiEvent;
}

export type FinishedRound = {
  id: bigint;
  phase: number;
  round: { endBlock: bigint; windowEnd: bigint };
};

export type SettleLookup = { status: "found"; kind: "settled" | "refunded"; hash: Hash } | { status: "failed" };

// Public RPCs cap the block range of one getLogs call, so the search walks forward in small steps.
const LOG_RANGE_BLOCKS = 1_000n;
const MAX_LOG_RANGES = 100n;

/**
 * The transaction that settled (or refunded) a Round, found from the contract's own event.
 * Settling happens right after the Window ends, so the search starts at the Round's pinned end
 * block and moves forward one bounded range at a time, stopping at the first hit.
 */
async function findSettleTx(
  client: PublicClient,
  address: Address,
  market: Market,
  round: FinishedRound,
  latest: { number: bigint; timestamp: bigint },
): Promise<SettleLookup> {
  // Block time is at least one second, so the blocks mined since the Window ended <= elapsed seconds.
  const elapsed = latest.timestamp > round.round.windowEnd ? latest.timestamp - round.round.windowEnd : 0n;
  const estimate = latest.number > elapsed + 10n ? latest.number - elapsed - 10n : 0n;
  const searchStart = round.round.endBlock > 0n ? round.round.endBlock : estimate;
  const events = { settled: eventOf(market, "Settled"), refunded: eventOf(market, "Refunded") };
  const args = { roundId: round.id };
  for (let step = 0n; step < MAX_LOG_RANGES; step++) {
    const fromBlock = searchStart + step * LOG_RANGE_BLOCKS;
    if (fromBlock > latest.number) break;
    const toBlock =
      fromBlock + LOG_RANGE_BLOCKS - 1n < latest.number ? fromBlock + LOG_RANGE_BLOCKS - 1n : latest.number;
    const [settled, refunded] = await Promise.all([
      client.getLogs({ address, event: events.settled, args, fromBlock, toBlock }),
      client.getLogs({ address, event: events.refunded, args, fromBlock, toBlock }),
    ]);
    if (settled[0]) return { status: "found", kind: "settled", hash: settled[0].transactionHash };
    if (refunded[0]) return { status: "found", kind: "refunded", hash: refunded[0].transactionHash };
  }
  return { status: "failed" };
}

/** Settle or refund transaction per finished Round, keyed by Round id. A failed lookup is retryable. */
export function useSettleTxs(payer: Payer, market: Market, rounds: FinishedRound[] | undefined) {
  const client = usePublicClient({ chainId: payer.chainId });
  const address = marketAddress(payer, market);
  const finished = rounds?.filter(round => isFinished(round.phase)) ?? [];
  return useQuery({
    queryKey: ["round-settle-txs", address, market, finished.map(round => round.id.toString()).join(",")],
    enabled: !!client && finished.length > 0,
    staleTime: Infinity,
    retry: 1,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const block = await client.getBlock();
      const latest = { number: block.number, timestamp: block.timestamp };
      const lookups = await Promise.all(
        finished.map(round =>
          findSettleTx(client, address, market, round, latest).catch((): SettleLookup => ({ status: "failed" })),
        ),
      );
      return Object.fromEntries(finished.map((round, index) => [round.id.toString(), lookups[index]])) as Record<
        string,
        SettleLookup
      >;
    },
  });
}

/**
 * What the contract holds to pay winners, read at one block: its real ETH or token balance, with
 * the contract's own funding and reserved views that make up most of it. Refunds still waiting
 * to be claimed are held too, so the total can exceed funding plus reserved.
 */
export function usePoolBalance(payer: Payer, market: Market) {
  const client = usePublicClient({ chainId: payer.chainId });
  const address = marketAddress(payer, market);
  return useQuery({
    queryKey: ["round-pool", address, payer.chainId],
    enabled: !!client && address !== zeroAddress,
    refetchInterval: 2000,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const block = await client.getBlock();
      const blockNumber = block.number;
      const contract = { address, abi: marketAbi[market] as typeof roundsAbi, blockNumber } as const;
      const [funding, reserved, token] = await Promise.all([
        client.readContract({ ...contract, functionName: "fundingBalance" }),
        client.readContract({ ...contract, functionName: "reservedBalance" }),
        client.readContract({ ...contract, functionName: "i_stakeToken" }),
      ]);
      if (token === zeroAddress) {
        const held = await client.getBalance({ address, blockNumber });
        return { held, funding, reserved, decimals: 18, symbol: "ETH" };
      }
      const [held, decimals, symbol] = await Promise.all([
        client.readContract({ address: token, abi: erc20Abi, functionName: "balanceOf", args: [address], blockNumber }),
        client.readContract({ address: token, abi: erc20Abi, functionName: "decimals", blockNumber }),
        client.readContract({ address: token, abi: erc20Abi, functionName: "symbol", blockNumber }),
      ]);
      return { held, funding, reserved, decimals, symbol };
    },
  });
}

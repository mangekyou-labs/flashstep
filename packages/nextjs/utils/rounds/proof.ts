"use client";

import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Abi, Address, Hash, PublicClient, erc20Abi, parseAbi, zeroAddress } from "viem";
import { usePublicClient } from "wagmi";
import { Payer } from "~~/config/payers";

export type Market = "updown" | "threshold";

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

export function embedSnippet(url: string, title: string): string {
  const embed = new URL(url);
  embed.searchParams.delete("round");
  return `<iframe src="${embed}" title="${title}" width="100%" height="900" style="border:0" allow="clipboard-write"></iframe>`;
}

/** The URL of this page's origin, available only after mount so server and client markup agree. */
export function useOrigin() {
  const [origin, setOrigin] = useState("");
  useEffect(() => setOrigin(window.location.origin), []);
  return origin;
}

const settleEvents = parseAbi([
  "event Settled(uint256 indexed roundId, uint8 result, uint256 a, uint256 b)",
  "event Refunded(uint256 indexed roundId)",
]);
const upDownRefund = parseAbi(["event Refunded(uint256 indexed roundId, address indexed payer, uint256 liquidity)"]);

export type ProofRow = {
  id: bigint;
  phase: number;
  round: { endBlock: bigint; windowEnd: bigint };
};

/**
 * Settle (or refund) transaction hash per Round, found from the contract's own event.
 * The search starts at the Round's pinned end block, so it never scans the whole chain.
 */
async function findSettleTx(
  client: PublicClient,
  address: Address,
  market: Market,
  row: ProofRow,
  latest: { number: bigint; timestamp: bigint },
): Promise<Hash | undefined> {
  // Base blocks are at least one second apart, so blocks since the Window ended <= elapsed seconds.
  const elapsed = latest.timestamp > row.round.windowEnd ? latest.timestamp - row.round.windowEnd : 0n;
  const estimate = latest.number > elapsed + 10n ? latest.number - elapsed - 10n : 0n;
  const fromBlock = row.round.endBlock > 0n ? row.round.endBlock : estimate;
  const args = { roundId: row.id };
  const settled = await client.getLogs({
    address,
    event: settleEvents[0],
    args,
    fromBlock,
    toBlock: latest.number,
  });
  if (settled[0]) return settled[0].transactionHash;
  const refundEvent = market === "updown" ? upDownRefund[0] : settleEvents[1];
  const refunded = await client.getLogs({ address, event: refundEvent, args, fromBlock, toBlock: latest.number });
  return refunded[0]?.transactionHash;
}

export function useSettleTxs(payer: Payer, market: Market, rows: ProofRow[] | undefined) {
  const client = usePublicClient({ chainId: payer.chainId });
  const address = market === "updown" ? payer.address : payer.thresholdAddress;
  const done = rows?.filter(row => row.phase === 3 || row.phase === 4) ?? [];
  return useQuery({
    queryKey: ["round-proof", address, market, done.map(row => `${row.id}:${row.phase}`).join(",")],
    enabled: !!client && done.length > 0,
    staleTime: Infinity,
    queryFn: async () => {
      if (!client) return {};
      const block = await client.getBlock();
      const latest = { number: block.number, timestamp: block.timestamp };
      const found = await Promise.all(done.map(row => findSettleTx(client, address, market, row, latest)));
      return Object.fromEntries(done.map((row, index) => [row.id.toString(), found[index]])) as Record<
        string,
        Hash | undefined
      >;
    },
  });
}

const poolAbi = [
  ...parseAbi([
    "function fundingBalance() view returns (uint256)",
    "function reservedBalance() view returns (uint256)",
  ]),
  ...parseAbi(["function i_stakeToken() view returns (address)"]),
] as Abi;

/** Funds the contract holds to pay winners: uncommitted funding plus amounts reserved for open Rounds. */
export function usePoolBalance(payer: Payer, market: Market) {
  const client = usePublicClient({ chainId: payer.chainId });
  const address = market === "updown" ? payer.address : payer.thresholdAddress;
  return useQuery({
    queryKey: ["round-pool", address, payer.chainId],
    enabled: !!client && address !== zeroAddress,
    refetchInterval: 2000,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const block = await client.getBlock();
      const contract = { address, abi: poolAbi, blockNumber: block.number } as const;
      const [funding, reserved, token] = (await Promise.all([
        client.readContract({ ...contract, functionName: "fundingBalance" }),
        client.readContract({ ...contract, functionName: "reservedBalance" }),
        client.readContract({ ...contract, functionName: "i_stakeToken" }),
      ])) as [bigint, bigint, Address];
      const [decimals, symbol] =
        token === zeroAddress
          ? ([18, "ETH"] as const)
          : await Promise.all([
              client.readContract({
                address: token,
                abi: erc20Abi,
                functionName: "decimals",
                blockNumber: block.number,
              }),
              client.readContract({ address: token, abi: erc20Abi, functionName: "symbol", blockNumber: block.number }),
            ]);
      return { funding, reserved, decimals, symbol };
    },
  });
}

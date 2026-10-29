"use client";

import { useQuery } from "@tanstack/react-query";
import { Address, erc20Abi, zeroAddress } from "viem";
import { usePublicClient } from "wagmi";
import { Payer } from "~~/config/payers";
import { readerAbi, roundsAbi } from "~~/utils/rounds/abi";

export const phaseNames = ["Trading", "Window", "Awaiting settlement", "Settled", "Refunded"];
export const resultNames = ["Awaiting result", "Up", "Down", "Tie", "Refunded"];

/** One block for all values that must agree; React never calculates an AMM quote or phase. */
export function useRound(payer: Payer, roundId: bigint | null, account?: Address) {
  const client = usePublicClient({ chainId: payer.chainId });
  return useQuery({
    queryKey: ["round", payer.address, payer.chainId, roundId?.toString(), account],
    enabled: !!client && payer.address !== zeroAddress,
    refetchInterval: 1000,
    retry: 1,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const block = await client.getBlock();
      const contract = { address: payer.address, abi: roundsAbi, blockNumber: block.number };
      const current = await client.readContract({ ...contract, functionName: "currentRound" });
      const id = roundId ?? current;
      if (!id) return { current, id, block, detail: undefined };
      const [round, phase, chance, position, claimable, token] = await Promise.all([
        client.readContract({ ...contract, functionName: "round", args: [id] }),
        client.readContract({ ...contract, functionName: "phase", args: [id] }),
        client.readContract({ ...contract, functionName: "chanceCents", args: [id] }),
        client.readContract({ ...contract, functionName: "positionOf", args: [id, account ?? zeroAddress] }),
        client.readContract({ ...contract, functionName: "claimable", args: [id, account ?? zeroAddress] }),
        client.readContract({ ...contract, functionName: "i_stakeToken" }),
      ]);
      const [reading, reference, decimals, symbol] = await Promise.all([
        client
          .readContract({ address: round.reader, abi: readerAbi, functionName: "preview", blockNumber: block.number })
          .catch(() => undefined),
        round.startBlock
          ? client
              .readContract({
                address: round.reader,
                abi: readerAbi,
                functionName: "read",
                args: [round.startBlock],
                blockNumber: block.number,
              })
              .catch(() => undefined)
          : undefined,
        token === zeroAddress
          ? 18
          : client.readContract({ address: token, abi: erc20Abi, functionName: "decimals", blockNumber: block.number }),
        token === zeroAddress
          ? "ETH"
          : client.readContract({ address: token, abi: erc20Abi, functionName: "symbol", blockNumber: block.number }),
      ]);
      return {
        current,
        id,
        block,
        detail: { round, phase, chance, position, claimable, token, decimals, symbol, reading, reference },
      };
    },
  });
}

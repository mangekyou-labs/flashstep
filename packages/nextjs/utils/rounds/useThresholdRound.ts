"use client";

import { useQuery } from "@tanstack/react-query";
import { Address, erc20Abi, zeroAddress } from "viem";
import { usePublicClient } from "wagmi";
import { Payer } from "~~/config/payers";
import { thresholdAbi } from "~~/utils/rounds/thresholdAbi";

/** All related values, including token metadata and payout previews, share one block. */
export function useThresholdRound(payer: Payer, selected: bigint | null, account?: Address) {
  const client = usePublicClient({ chainId: payer.chainId });
  return useQuery({
    queryKey: ["threshold", payer.thresholdAddress, payer.chainId, selected?.toString(), account],
    enabled: !!client && payer.thresholdAddress !== zeroAddress,
    refetchInterval: 1000,
    retry: 1,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const block = await client.getBlock();
      const contract = { address: payer.thresholdAddress, abi: thresholdAbi, blockNumber: block.number };
      const current = await client.readContract({ ...contract, functionName: "currentRound" });
      const id = selected ?? current;
      if (!id) return { id, current, block, detail: undefined };
      const [round, phase, position, claimable, token, value, yesWin, noWin] = await Promise.all([
        client.readContract({ ...contract, functionName: "round", args: [id] }),
        client.readContract({ ...contract, functionName: "phase", args: [id] }),
        client.readContract({ ...contract, functionName: "positionOf", args: [id, account ?? zeroAddress] }),
        client.readContract({ ...contract, functionName: "claimable", args: [id, account ?? zeroAddress] }),
        client.readContract({ ...contract, functionName: "i_stakeToken" }),
        client.readContract({ ...contract, functionName: "currentValue", args: [id] }).catch(() => undefined),
        client.readContract({ ...contract, functionName: "quoteStake", args: [id, account ?? zeroAddress, 0, 0n] }),
        client.readContract({ ...contract, functionName: "quoteStake", args: [id, account ?? zeroAddress, 1, 0n] }),
      ]);
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
      return {
        id,
        current,
        block,
        detail: { round, phase, position, claimable, token, value, decimals, symbol, yesWin, noWin },
      };
    },
  });
}

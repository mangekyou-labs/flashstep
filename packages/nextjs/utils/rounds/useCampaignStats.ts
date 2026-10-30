"use client";

import { useQuery } from "@tanstack/react-query";
import { Abi, Address, PublicClient, erc20Abi, parseEventLogs, parseUnits, zeroAddress } from "viem";
import { usePublicClient } from "wagmi";
import { Payer } from "~~/config/payers";
import { roundsAbi } from "~~/utils/rounds/abi";
import { RoundLog, RoundStats, campaignTotals, thresholdRoundStats, upDownRoundStats } from "~~/utils/rounds/stats";
import { thresholdAbi } from "~~/utils/rounds/thresholdAbi";

// Public RPCs cap the block range of one getLogs call.
const LOG_RANGE_BLOCKS = 1_000n;
/** Native ETH stake, and the fallback when neither market is configured. */
const ETH = { decimals: 18, symbol: "ETH" };

async function campaignLogs(client: PublicClient, address: Address, abi: Abi, fromBlock: bigint, toBlock: bigint) {
  const logs: RoundLog[] = [];
  for (let from = fromBlock; from <= toBlock; from += LOG_RANGE_BLOCKS) {
    const to = from + LOG_RANGE_BLOCKS - 1n < toBlock ? from + LOG_RANGE_BLOCKS - 1n : toBlock;
    const raw = await client.getLogs({ address, fromBlock: from, toBlock: to });
    logs.push(...(parseEventLogs({ abi, logs: raw }) as unknown as RoundLog[]));
  }
  return logs;
}

async function stakeToken(client: PublicClient, address: Address, abi: Abi) {
  const token = (await client.readContract({ address, abi, functionName: "i_stakeToken" })) as Address;
  if (token === zeroAddress) return ETH;
  const [decimals, symbol] = await Promise.all([
    client.readContract({ address: token, abi: erc20Abi, functionName: "decimals" }),
    client.readContract({ address: token, abi: erc20Abi, functionName: "symbol" }),
  ]);
  return { decimals, symbol };
}

/** Every Round's volume, players and payer profit or loss, read from both contracts' events. */
export function useCampaignStats(payer: Payer) {
  const client = usePublicClient({ chainId: payer.chainId });
  return useQuery({
    queryKey: ["campaign-stats", payer.address, payer.thresholdAddress, payer.chainId],
    enabled: !!client,
    refetchInterval: 2000,
    retry: 1,
    queryFn: async () => {
      if (!client) throw new Error("Connect to the Campaign network.");
      const latest = await client.getBlockNumber();
      const rounds: RoundStats[] = [];
      let token: { decimals: number; symbol: string } | undefined;
      if (payer.address !== zeroAddress) {
        const abi = roundsAbi as Abi;
        const [logs, payout, owner, meta] = await Promise.all([
          campaignLogs(client, payer.address, abi, payer.fromBlock, latest),
          client.readContract({ address: payer.address, abi: roundsAbi, functionName: "PAYOUT" }),
          client.readContract({ address: payer.address, abi: roundsAbi, functionName: "owner" }),
          stakeToken(client, payer.address, abi),
        ]);
        rounds.push(...upDownRoundStats(logs, payout, owner));
        token = meta;
      }
      if (payer.thresholdAddress !== zeroAddress) {
        const abi = thresholdAbi as Abi;
        const [logs, meta] = await Promise.all([
          campaignLogs(client, payer.thresholdAddress, abi, payer.fromBlock, latest),
          stakeToken(client, payer.thresholdAddress, abi),
        ]);
        rounds.push(...thresholdRoundStats(logs));
        token ??= meta;
      }
      token ??= ETH;
      const cost = payer.campaignCost === undefined ? undefined : parseUnits(payer.campaignCost, token.decimals);
      const totals = campaignTotals(rounds, cost);
      return { rounds, totals, token, block: latest };
    },
  });
}

import { Address, zeroAddress } from "viem";

const knownExplorers: Record<number, string> = {
  8453: "https://basescan.org",
  84532: "https://sepolia.basescan.org",
};
/**
 * Block explorer base URL for one payer: its own override, then NEXT_PUBLIC_EXPLORER_URL, then the
 * well-known explorer for the chain. Local chains have none, so Round pages then show plain hashes.
 */
function explorerFor(chainId: number, payerOverride: string | undefined): string {
  return (payerOverride || process.env.NEXT_PUBLIC_EXPLORER_URL || knownExplorers[chainId] || "").replace(/\/+$/, "");
}

/** One config entry per payer. Addresses are fixed at build time, never taken from URL input. */
export const payers = {
  DEGEN: {
    name: "Degen",
    ticker: "DEGEN",
    logo: "/rounds/degen.svg",
    accent: "#6d28d9",
    up: "#167349",
    down: "#b6333b",
    address: (process.env.NEXT_PUBLIC_ROUNDS_ADDRESS || zeroAddress) as Address,
    thresholdAddress: (process.env.NEXT_PUBLIC_THRESHOLD_ADDRESS || zeroAddress) as Address,
    chainId: 31337,
    quoteTicker: "ETH",
    explorerUrl: explorerFor(31337, process.env.NEXT_PUBLIC_DEGEN_EXPLORER_URL),
    /** What the payer paid for the Campaign, in the stake token (decimal string), for the payer stats view. */
    campaignCost: process.env.NEXT_PUBLIC_DEGEN_CAMPAIGN_COST || "0.5",
    /** First block to read Campaign events from (the deploy block). */
    fromBlock: BigInt(process.env.NEXT_PUBLIC_DEGEN_FROM_BLOCK || "0"),
  },
  BASE: {
    name: "Base",
    ticker: "BASE",
    logo: "/rounds/base.svg",
    accent: "#174bd6",
    up: "#116a42",
    down: "#ae2935",
    address: (process.env.NEXT_PUBLIC_BASE_ROUNDS_ADDRESS ||
      process.env.NEXT_PUBLIC_ROUNDS_ADDRESS ||
      zeroAddress) as Address,
    thresholdAddress: (process.env.NEXT_PUBLIC_BASE_THRESHOLD_ADDRESS ||
      process.env.NEXT_PUBLIC_THRESHOLD_ADDRESS ||
      zeroAddress) as Address,
    chainId: 31337,
    quoteTicker: "ETH",
    explorerUrl: explorerFor(31337, process.env.NEXT_PUBLIC_BASE_EXPLORER_URL),
    campaignCost: process.env.NEXT_PUBLIC_BASE_CAMPAIGN_COST || "0.5",
    fromBlock: BigInt(process.env.NEXT_PUBLIC_BASE_FROM_BLOCK || "0"),
  },
} as const;
export type Payer = (typeof payers)[keyof typeof payers];
export type Market = "updown" | "threshold";
/** The payer's contract for a market; the zero address when it is not configured. */
export function marketAddress(payer: Payer, market: Market): Address {
  return market === "updown" ? payer.address : payer.thresholdAddress;
}
export function payerFor(key: string | null): Payer {
  return payers[key?.toUpperCase() as keyof typeof payers] || payers.DEGEN;
}

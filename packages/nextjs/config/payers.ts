import { Address, zeroAddress } from "viem";

const knownExplorers: Record<number, string> = {
  8453: "https://basescan.org",
  84532: "https://sepolia.basescan.org",
};
/** Block explorer base URL for a chain. Local chains have none unless NEXT_PUBLIC_EXPLORER_URL is set. */
function explorerFor(chainId: number): string {
  return (process.env.NEXT_PUBLIC_EXPLORER_URL || knownExplorers[chainId] || "").replace(/\/+$/, "");
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
    explorerUrl: explorerFor(31337),
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
    explorerUrl: explorerFor(31337),
  },
} as const;
export type Payer = (typeof payers)[keyof typeof payers];
export function payerFor(key: string | null): Payer {
  return payers[key?.toUpperCase() as keyof typeof payers] || payers.DEGEN;
}

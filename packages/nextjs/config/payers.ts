import { Address, zeroAddress } from "viem";

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
  },
} as const;
export type Payer = (typeof payers)[keyof typeof payers];
export function payerFor(key: string | null): Payer {
  return payers[key?.toUpperCase() as keyof typeof payers] || payers.DEGEN;
}

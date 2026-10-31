import { type Payer } from "~~/utils/rounds/brandConfig";

export type { Payer };
export type Market = "updown" | "threshold";

export function marketAddress(payer: Payer, market: Market): `0x${string}` {
  return market === "updown" ? payer.address : payer.thresholdAddress;
}

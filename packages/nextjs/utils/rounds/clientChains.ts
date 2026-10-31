import { type Chain } from "viem";
import { base, baseSepolia, mainnet } from "viem/chains";

/**
 * Chains the page can read. The return keeps each chain's id as a literal so
 * `getPublicClient` stays defined. Callers keep Base off `targetNetworks` so the burner still shows.
 */
export function clientChains<const T extends readonly [Chain, ...Chain[]]>(
  targetNetworks: T,
): readonly [...T, typeof base, typeof baseSepolia, typeof mainnet] {
  const present = new Set(targetNetworks.map(chain => chain.id));
  const extras = [base, baseSepolia, mainnet].filter(chain => !present.has(chain.id));
  return [...targetNetworks, ...extras] as readonly [...T, typeof base, typeof baseSepolia, typeof mainnet];
}

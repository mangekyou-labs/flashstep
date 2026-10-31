// Run with: node --test packages/nextjs/utils/rounds/clientChains.test.ts (Node 24 strips the types).
// Relative import: node --test cannot resolve the `~~` tsconfig alias.
import { clientChains } from "./clientChains.ts";
import assert from "node:assert/strict";
import { test } from "node:test";
import { foundry } from "viem/chains";

test("a Foundry-only target list still exposes Base on the page client list", () => {
  const ids = clientChains([foundry]).map(chain => chain.id);
  assert.deepEqual(ids, [31337, 8453, 84532, 1]);
});

# Proof and sharing on the Rounds page (#10)

## What the page shows
- Recent Rounds: result plus Start Reading → End Reading. The threshold table shows the threshold and End Reading only: `ThresholdPots` stores no Start Reading (its Round struct has `endReading`, `endValue` and `threshold`), so there is nothing to show.
- Finished Rounds link to their transaction on the payer's block explorer: "Settle tx" for Settled Rounds, "Refund tx" for Refunded ones. Without an explorer the short hash is shown as plain text and a note under the table says no explorer is configured.
- Pool balance (user story 40) is the contract's real balance: `getBalance` for an ETH stake, `balanceOf` for an ERC20 stake. That is the money that can pay winners. `fundingBalance` and `reservedBalance` are shown beneath it as the breakdown. The real balance can exceed their sum by refund credit that is owed but not yet withdrawn, so the headline is read from the chain rather than computed. It refreshes every 2 seconds.
- Share bar: X and Telegram intents, plus "Copy link for Discord" (Discord has no share intent). Links carry `?brand=…&round=N` (and `market=threshold`).

## Finding the settle or refund transaction
`findSettleTx` (`packages/nextjs/utils/rounds/proof.ts`) filters the `Settled` and `Refunded` events by the indexed `roundId`. It starts at the Round's `endBlock` (or a block estimated from the Window end when none was captured, as for refunds) and scans forward in 1000 block ranges, at most 100 ranges, so a public RPC's `eth_getLogs` range limit cannot block it. A failed lookup shows "Lookup failed" with a Retry button instead of staying on "Looking up…". Event ABIs come from `abi.ts` and `thresholdAbi.ts`.

## Embedding
`next.config.ts` sets `Content-Security-Policy: frame-ancestors ${ROUNDS_FRAME_ANCESTORS || "*"}` on `/rounds`. Set `ROUNDS_FRAME_ANCESTORS` to a space-separated origin list to restrict hosts. A static IPFS export has no response headers, so the CSP does not apply there. There is no embed button on the page. A payer embeds it with:

```html
<iframe src="https://<host>/rounds?brand=BASE" width="100%" height="900" style="border:0"></iframe>
```

## Configuration
- `explorerUrl` in `brand.json` is the payer's block explorer base URL (for local chains, which have no known explorer). Not `NEXT_PUBLIC_DEGEN_EXPLORER_URL` in `config/payers.ts`.
- `ROUNDS_FRAME_ANCESTORS`: allowed embedders (server side).

## Smoke run
`node scripts/proof-smoke.mjs` (needs anvil, forge and playwright-cli; ports 8545, 3010 and 3011 free). It starts its own anvil, Next dev server and host page, then stops them. It checks 19 things, including: the frame-ancestors header; result, Readings and settle link on up/down and threshold rows; a "Refund tx" link; pool balance equal to the contract balance and refreshed after funding; share-link Round; the copy button and clipboard; the iframe; the failed-lookup and Retry path; no horizontal overflow at 375, 768 and 1280px; no console errors; and with no explorer, plain hashes plus the visible note and a restricted `ROUNDS_FRAME_ANCESTORS` blocking a foreign embedder. Not covered: a live Base RPC, and Discord (copy only).

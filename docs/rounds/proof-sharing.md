# Proof and sharing on the Rounds page (#10)

## What the page shows
- Recent Rounds: result plus Start Reading → End Reading (threshold: End Reading against the threshold).
- Settled Rounds link to their settle tx on the payer's block explorer (found via the `Settled` event, indexed by roundId, scanned from the Round's `endBlock`). Without an explorer URL the short hash is shown instead.
- Pool balance = `fundingBalance` + `reservedBalance`, read from the contract views (not recomputed in TS).
- Share bar: X and Telegram intents, plus "copy link" (Discord has no share intent). Links carry `?brand=…&round=N` (and `market=threshold`).

## Embedding
`next.config.ts` sets `Content-Security-Policy: frame-ancestors ${ROUNDS_FRAME_ANCESTORS || "*"}` on `/rounds`. Set `ROUNDS_FRAME_ANCESTORS` to a space-separated origin list to restrict hosts. A static IPFS export has no response headers, so the CSP does not apply there.

## Smoke run (playwright-cli, local anvil fixture)
- `curl -I /rounds`: 200, `frame-ancestors *`, no X-Frame-Options.
- Up/down: settled row shows Up, `1 → 1.007528` and a basescan link matching the fixture tx; pending row shows "Awaiting settlement".
- Threshold: Yes, threshold 1 ETH, End Reading 1.007528 ETH, settle link.
- Pool balance on page matched `cast call fundingBalance + reservedBalance` (10 ETH threshold fixture; 11 ETH after an extra fund on the up/down pool).
- Iframe host page embedding `/rounds?brand=BASE&round=1` rendered Round #1 fully.
- 375px width: scrollWidth 375 = innerWidth (no overflow). Console: 0 errors.

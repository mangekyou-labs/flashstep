# 07: The branded up/down Round page

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 03

**Status:** in-progress

**Assignee:** MrSufferer

**What to build:** the payer-branded Round page for up/down Rounds, running against a local chain with the mock pool. Kalshi design language as in the prototype (`.scratch/paid-fast-rounds/prototype/PROTOTYPE-demo.html?v=player` on branch `prototype/demo-payers-see`): light theme, cents pricing, Up green and Down red, a chance headline, a live chart with a dashed reference line, a countdown to the end of trading, a trade panel with the Stake cap and "To win". Branding (name, ticker, colours, logo) comes from per-payer config. Motion follows emil-design-eng. Phase, quotes, positions and claimables come from contract views, never recomputed in TypeScript. Do not frame the payer as "the house".

- [ ] A Player connects, buys and sells Up or Down, sees their position, and claims after settlement
- [ ] Trades over the Stake cap or after trading closes are blocked in the UI with a clear message
- [ ] The page rolls to the next Round on schedule
- [ ] Changing the brand config changes the name, ticker and colours
- [ ] A `playwright-cli` smoke run covers buy, settle and claim on the local chain

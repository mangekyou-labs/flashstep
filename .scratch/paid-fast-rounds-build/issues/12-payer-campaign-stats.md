# 12: Payer Campaign stats

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 07, 08

**Status:** ready-for-agent

**What to build:** a payer view of the Campaign: per Round, the volume, player count and the payer's profit or loss on seeded liquidity or Opening stakes, and the Campaign total next to the US$300 fee, so the payer can judge the pilot as marketing spend.

- [ ] Per-Round volume, player count and payer profit or loss match the contract events
- [ ] The Campaign total updates as Rounds settle
- [ ] Covered by a `playwright-cli` smoke run

# 03: Selling, Tie refunds and back-to-back Rounds

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 02

**Status:** ready-for-agent

**What to build:** finish UpDownRounds for a Campaign. Players sell before trading closes. A Tie refunds each Player exactly what they paid in that Round (buys minus sell proceeds, floored at zero). Rounds follow the Campaign schedule (trading phase 5-30 s, Window 1-30 s), so the next Round trades while the last one's Window runs and nobody calls open. The owner withdraws leftover liquidity after settlement, changes Campaign settings only between Rounds, and can stop the Campaign.

- [ ] A sell outside trading reverts; a sell returns the quoted amount
- [ ] A Tie refunds net paid per Player, and nothing else is paid out
- [ ] `currentRound()` advances on schedule; two overlapping Rounds keep separate share books and results
- [ ] Settings changed mid-Round apply only from the next Round
- [ ] A stopped Campaign opens no new Rounds; existing Rounds still settle and pay
- [ ] Owner-only actions revert for anyone else
- [ ] Fuzzed trade sequences across overlapping Rounds: the contract never owes more than it holds

# 02: One up/down Round in ETH, end to end

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 01

**Status:** ready-for-agent

**What to build:** UpDownRounds, built from the Speedrun AMM (Yes/No shares, buy quotes, the LP role), with ETH as the stake. The payer (owner) funds a balance and seeds one Round. Players buy Up or Down only in the trading phase, up to the Stake cap. The start Reading is pinned when trading closes. After the Window ends anyone calls `settle`: Up if end > start, Down if lower. Winners `claim` at the Payout. There is no Oracle and no `report`.

- [ ] `phase(roundId)` reads Trading → Window → Awaiting settlement → settled, with no transaction needed to move between them
- [ ] A buy outside trading reverts with a custom error
- [ ] A buy that takes a Player's stake in the Round over the Stake cap reverts, counting earlier buys
- [ ] `settle` before the Window ends reverts; after it, anyone can call it, and both Readings are stored and readable
- [ ] Winners claim the Payout, losers get nothing, a second claim pays nothing
- [ ] `quote`, `positionOf` and `claimable` views match what buy and claim actually do
- [ ] Reentrancy protection and checks-effects-interactions on `claim` and `settle`

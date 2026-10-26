# 08: Threshold Rounds on the Round page

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 04, 07

**Status:** ready-for-agent

**What to build:** the Round page shows threshold Rounds from ThresholdPots: the threshold (price or market cap) against the current value, Yes/No staking, what the Player would win now, a note that the payout shrinks if others join their side, and claiming, including refunds on Tie and Unmatched.

- [ ] A Player stakes Yes or No and claims a win or a refund
- [ ] "To win" matches the contract's `claimable` at the current split
- [ ] Unmatched and Tie Rounds show as refunds
- [ ] A `playwright-cli` smoke run covers stake, settle and claim

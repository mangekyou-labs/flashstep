# 08: Threshold Rounds on the Round page

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 04, 07

**Status:** resolved

**What to build:** the Round page shows threshold Rounds from ThresholdPots: the threshold (price or market cap) against the current value, Yes/No staking, what the Player would win now, a note that the payout shrinks if others join their side, and claiming, including refunds on Tie and Unmatched.

- [x] A Player stakes Yes or No and claims a win or a refund
- [x] "To win" matches the contract's `claimable` at the current split
- [x] Unmatched and Tie Rounds show as refunds
- [x] A `playwright-cli` smoke run covers stake, settle and claim

## Resolution

Implemented in [PR #25](https://github.com/mangekyou-labs/flashstep/pull/25), closing GitHub issue #9 when merged. The Threshold Round page uses contract-owned quotes and claimable amounts, including virtual payer Opening stakes, and supports ETH and ERC-20 staking. See [implementation and smoke instructions](../../../docs/rounds/threshold-page.md).

Validation: 120 threshold/reading tests passed, five optional fork tests skipped; TypeScript and changed-file ESLint passed. Local `playwright-cli` runs covered both stake sides, payout dilution, cumulative cap refusal, rollover, historical win claims, Tie and Unmatched refunds, six-decimal approval/stake/claim and precision rejection, responsive widths, both brands, and existing Up/Down positions.

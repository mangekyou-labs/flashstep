# 04: Threshold Rounds on a Pot, in ETH

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 01

**Status:** ready-for-agent

**What to build:** ThresholdPots, a pari-mutuel Pot per Round (no AMM; see ADR 0003 and ADR 0004), with ETH as the stake. Each Round asks whether the price, or the market cap, will be above a threshold at the end Reading. The payer sets the threshold or the rule for it, and pre-funds a fixed Opening stake that goes on both sides of every Round. Players stake Yes or No only in trading, up to the Stake cap; there is no selling. Rounds follow the same schedule and overlap as UpDownRounds.

- [ ] The Opening stake is on both sides of each Round and settles like any other stake
- [ ] A stake outside trading, or over the Stake cap, reverts
- [ ] Price and market cap thresholds both settle correctly from the end Reading: Yes above, No below, Tie on equal
- [ ] One side with no stake at the end of trading is Unmatched and settles without a Reading
- [ ] Winners get stake × pot ÷ winning side total, rounded down; Tie and Unmatched refund every stake; no fee
- [ ] A double claim pays nothing; `claimable` matches `claim`
- [ ] Fuzzed stake sequences: the contract never owes more than it holds

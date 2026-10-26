# 05: Outage refunds and unsettled expiry

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 03, 04

**Status:** ready-for-agent

**What to build:** in both contracts, a Round that cannot get a valid Reading by a deadline after its Window refunds every stake, and a Round left unsettled for 24 hours (the creator-feed Expired rule) refunds every stake. A pool or sequencer outage never forces a guessed result.

- [ ] A missing end observation on the mock pool leads to a refund in UpDownRounds and in ThresholdPots
- [ ] A Round left unsettled past 24 hours refunds on claim, with no settle needed
- [ ] Refunded stakes are claimable once and claims never expire
- [ ] The payer's seeded liquidity and Opening stake come back to the payer on refund

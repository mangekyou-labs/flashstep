# 06: The payer's own token or USDC as the stake token

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 03, 04

**Status:** ready-for-agent

**What to build:** the stake token is fixed at deploy for both contracts: the payer's ERC-20, USDC, or ETH. Every amount (Stake cap, Opening stake, seeded liquidity) is in that token.

- [ ] Both contracts work with an ERC-20 stake token and with ETH
- [ ] Every UpDownRounds and ThresholdPots test from earlier tickets runs against both token kinds
- [ ] Sending ETH to an ERC-20 deployment, or skipping approval, reverts cleanly
- [ ] A 6-decimal token (USDC) and an 18-decimal token both pay out correctly

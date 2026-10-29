# 06: The payer's own token or USDC as the stake token

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 03, 04

**Status:** resolved

**Assignee:** MrSufferer

**What to build:** the stake token is fixed at deploy for both contracts: the payer's ERC-20, USDC, or ETH. Every amount (Stake cap, Opening stake, seeded liquidity) is in that token.

- [x] Both contracts work with an ERC-20 stake token and with ETH
- [x] Every UpDownRounds and ThresholdPots test from earlier tickets runs against both token kinds
- [x] Sending ETH to an ERC-20 deployment, or skipping approval, reverts cleanly
- [x] A 6-decimal token (USDC) and an 18-decimal token both pay out correctly

## Resolution

Implemented for [GitHub #7](https://github.com/mangekyou-labs/flashstep/issues/7) in [PR #22](https://github.com/mangekyou-labs/flashstep/pull/22). Both contracts fix their ETH/ERC-20 asset at deployment, use raw stake units and exact SafeERC20 transfers, and retain isolated pull claims. Prior suites run with both assets; adversarial mocks, decimal fuzzing and pinned native Base USDC tests cover transfer failures and payouts. See [interface, assumptions and validation](../../../docs/implementation/stake-token.md).

# 11: Payer deploy and Campaign setup

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 05, 06

**Status:** ready-for-agent

**What to build:** a deploy script the payer runs from its own wallet, so the payer owns both contracts and the developer holds nothing. It sets the stake token, pool, trading phase, Window, Stake cap, market types and thresholds, and funds the seeded liquidity and Opening stakes. It ships with a Stake cap rule of thumb from pool liquidity and Window length (shorter Windows mean a lower cap). Deploy commands need an interactive password prompt: leave running them to the user.

- [ ] After the script runs, the payer's address is the owner of both contracts and the developer has no role
- [ ] Every Campaign setting is set by the script and readable from the contracts
- [ ] The Stake cap rule of thumb is documented and checked against the fork Reading from ticket 01
- [ ] A local-chain run of the script, then the settle bot and the page, works end to end

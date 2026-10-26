# 14: QA: pilot rehearsal on Base Sepolia

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 13

**Status:** ready-for-human

**Type:** HITL. The user deploys (the deploy needs an interactive password prompt) and judges the result; the agent prepares the checklist and records findings.

**What to build:** a manual QA pass on the finished product. Run a full Campaign on Base Sepolia (deploy, page, settle bot, several Rounds of each type, at least one Tie or Unmatched), and check the TWAP lookback and Stake cap rule of thumb against a real qualifying Base pool on a mainnet fork.

- [ ] The user deploys a Campaign to Base Sepolia from their own wallet with the deploy script
- [ ] Several Rounds of both types run and are settled by the settle bot, including at least one Tie or Unmatched
- [ ] A `playwright-cli` smoke run passes against the Sepolia deployment
- [ ] A mainnet-fork read of a real qualifying pool confirms the lookback gives usable Readings and the Stake cap rule of thumb holds
- [ ] Bugs found are filed as new tickets; the product is judged ready to pilot, or not

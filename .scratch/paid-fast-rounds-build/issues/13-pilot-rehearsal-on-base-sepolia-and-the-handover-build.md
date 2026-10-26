# 13: Pilot rehearsal on Base Sepolia and the handover build

**Source:** [the spec](../../paid-fast-rounds/spec.md). Building is gated: start only after a payer makes a Paid commitment in [Run the outreach](../../run-the-outreach/task.md).

**Blocked by:** 09, 10, 11, 12

**Status:** ready-for-agent

**What to build:** a full Campaign run on Base Sepolia (deploy, page, settle bot, several Rounds of each type, at least one Tie or Unmatched), and the Round page packaged as a static build plus config that the payer can host after the pilot.

- [ ] A Base Sepolia Campaign runs several Rounds of both types, settled by the bot
- [ ] A `playwright-cli` smoke run passes against the Sepolia deployment
- [ ] The static build plus a new brand config serves a working page with no developer hosting
- [ ] A short runbook covers deploy, bot, hosting and handover

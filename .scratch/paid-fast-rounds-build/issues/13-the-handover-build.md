# 13: The handover build

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 09, 10, 11, 12

**Status:** ready-for-agent

**What to build:** the Round page packaged as a static build plus per-payer config that a payer can host with no developer involvement, and a short runbook for deploying, running the settle bot, hosting the page and taking over after the pilot.

- [ ] The static build plus a new brand config serves a working page with no developer hosting
- [ ] A `playwright-cli` smoke run passes against the static build on a local chain with the mock pool, covering both Round types and at least one Tie or Unmatched
- [ ] A short runbook covers deploy, settle bot, hosting and handover

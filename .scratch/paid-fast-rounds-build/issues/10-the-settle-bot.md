# 10: The settle bot

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 03, 04

**Status:** ready-for-agent

**What to build:** a small script that watches both contracts and calls `settle` on every Round whose Window has ended. It has no privileges and only pays gas. The developer runs it during the pilot and the payer can run it after.

- [ ] On a local chain, Rounds of both types settle on time with no Player calling settle
- [ ] A Round already settled by someone else is skipped without a failed transaction
- [ ] Restarting the bot picks up any unsettled Rounds
- [ ] The RPC it uses and its request rate are configurable; Base public RPC limits are noted in the resolution

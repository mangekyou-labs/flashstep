# 10: The settle bot

**Source:** [the spec](../../paid-fast-rounds/spec.md).

**Blocked by:** 03, 04

**Status:** resolved

**Assignee:** MrSufferer

**What to build:** a small script that watches both contracts and calls `settle` on every Round whose Window has ended. It has no privileges and only pays gas. The developer runs it during the pilot and the payer can run it after.

- [x] On a local chain, Rounds of both types settle on time with no Player calling settle
- [x] A Round already settled by someone else is skipped without a failed transaction
- [x] Restarting the bot picks up any unsettled Rounds
- [x] The RPC it uses and its request rate are configurable; Base public RPC limits are noted in the resolution

## Resolution

Implemented for [GitHub #11](https://github.com/mangekyou-labs/flashstep/issues/11). `yarn settle:bot` watches both contracts with a dedicated gas wallet, captures their exact Reading boundaries, simulates settlement and finalizes eligible refunds. Restart recovery replays `RoundSeeded` logs, including stopped Campaigns, and waits for existing pending wallet transactions. RPC, request interval, polling and scan range are configurable.

Validation: `forge build` and the executable `node scripts-js/settleBot.smoke.js` local-chain smoke passed. The actual CLI settles both real Round contracts on time against the existing pool mocks, restarts with pending captures and recovers both stopped Campaigns, skips settled Rounds from another wallet without sending transactions, and verifies RPC request pacing through a forwarding server. Invalid rate configuration fails at startup. No JS test runner is added.

Base's public RPC endpoints are rate limited and unsuitable for production; its [throughput and limits documentation](https://docs.base.org/specifications/transactions/throughput-and-limits) does not publish a universal numeric requests-per-second allowance. Use a dedicated provider and its plan's limits. The bot's default 50ms response-to-next-request interval allows at most roughly 20 requests/second before latency; this is the bot's configurable ceiling, not a Base allowance. Exact-block inclusion and a concurrent competing settlement cannot be guaranteed. See the [runbook, capture timing, pending-transaction recovery and validation evidence](../../../docs/implementation/settle-bot.md).

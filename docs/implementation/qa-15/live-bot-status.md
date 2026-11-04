# Live bot rehearsal — 2026-11-04

**Verdict: blocked; normal settlement has not passed.** The owner started the bot using a dedicated gas-funded wallet. Its submitted Round 1 transactions succeeded, but both emitted `Refunded`, not a normal price-based outcome. Public receipt/result readback is in [live-bot-readback.json](live-bot-readback.json). No agent signed or submitted transactions.

| Contract | Round 1 transaction | Stored result | Event |
| --- | --- | --- | --- |
| UpDownRounds | [0x15f6754f…18dda](https://sepolia.basescan.org/tx/0x15f6754f0e8e03a39f882344672a22f0cee851cf7610fe9f616dd6fe3bf18dda) | 4 | Refunded |
| ThresholdPots | [0x05649ccd…b365e](https://sepolia.basescan.org/tx/0x05649ccdb28d74e90bcc43db5ead112f41558d5ac65fd2e01bf1370a476b365e) | 5 | Refunded |

The owner then reported repeated `missed_boundary`, including UpDown round 5336 at timestamp1793756965 and Threshold round5342 at1793757057. This log means the bot abandoned a capture after refreshing the head: `latest.timestamp + 2 !== boundary`. It does not prove the actual contract boundary had already elapsed; the refreshed head may simply have advanced within the preceding two seconds.

## High-severity timing incompatibility

The bot in `packages/foundry/scripts-js/settleBot.js:140` and `:300` assumes the next block arrives two seconds later. Its restart discovery at `:267` treats 32 blocks as roughly a minute. Read-only RPC samples instead show consecutive canonical heights sharing whole-second timestamps, with about five heights per second: e.g.54177320–54177324 all timestamp1793757333. The attached sample preserves a fresh observation.

[Base's official Denim specification](https://docs.base.org/upgrades/denim/200ms-blocks) confirms native 200ms blocks activated on Base Sepolia on October21,2026; EVM `block.timestamp` remains in whole seconds. The bot's two-second lead is therefore approximately ten blocks early, not one block early. Its 32-block recovery horizon covers roughly6.4seconds, not64seconds. Sequential RPC work also makes its initial loop timestamp stale before the refreshed-head guard; the owner RPC latency has not been measured, so no exclusive attribution to provider speed is claimed.

Changing the RPC alone cannot correct these assumptions. Increasing round durations also leaves the exact-boundary submission assumption intact. Preserve exact contract Reading semantics; do not substitute a later price or simply remove the guard.

## Recovery implemented — live rerun pending

The owner authorized the runtime fix. The bot now supports native 200ms blocks: it prepares capture transactions ahead, prioritizes them over background RPC work, checks a fresh timestamp immediately before each broadcast, and reserves unresolved local nonces. Restart discovery uses elapsed chain time instead of a fixed 32-block assumption. Exact contract Reading semantics remain intact; the reader and both deployed contracts remain usable without redeployment.

The native regression initially failed at the cutoff with the old bot. Validation uses actual local Solidity deployments and the actual CLI, five blocks per whole-second timestamp, 60ms added RPC latency, restart recovery beyond 32 blocks, and three simultaneous captures. Stored results must be UpDown Tie and threshold Yes, with no reverts. See [the test log](logs/settle-bot-denim-smoke.log) and [operating documentation](../settle-bot.md). This controlled fixture establishes local behavior, not public-chain inclusion reliability.

Restart the owner-operated process with `bash /private/tmp/flashstep-qa-15/run-sepolia-qa-bot.sh`; stop the old process with Ctrl+C first. Its `ready` event should include `blockTimeMs:200`. Keep capture and settlement transaction hashes for fresh public receipt/result readback. No agent has signed on Sepolia. Several actual captures and normal settlements, including Tie/Unmatched and restart recovery, remain required. Issue #39 stays open for live confirmation; issue #15 remains not ready to pilot.

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

## Next work

Stop the current bot with Ctrl+C. A timing fix needs a regression harness with native 200ms blocks, repeated whole-second timestamps, realistic RPC latency, simultaneous boundaries for both contracts and restart recovery. Schedule discovery and historical settlement must not delay deadline-sensitive captures. Recheck the reader/contract assumptions and determine whether the existing contracts remain usable before proposing a redeployment.

After that fix, rerun the owner-operated bot against these contracts if compatible, and record several actual captures and normal settlements, including Tie/Unmatched and restart recovery. Existing local two-second Anvil smoke results remain valid for that fixture but do not establish Denim compatibility. No runtime source patch, redeployment, or successful live capture is claimed here. Issue15 remains open and not ready to pilot.

# Live bot rehearsal — 2026-11-04

**Verdict: live acceptance pending; normal public-chain settlement has not passed.** The owner started the bot using a dedicated gas-funded wallet. Its submitted Round 1 transactions succeeded, but both emitted `Refunded`, not a normal price-based outcome. Public receipt/result readback is in [live-bot-readback.json](live-bot-readback.json). No agent signed or submitted transactions.

> Latest runtime revision: batched preparation/submission passes native restart and three-Round overlap at 300ms simulated RPC latency. The previous failed 300ms result below is historical. The owner may run one supervised rehearsal with the updated launcher; stop and inspect any `capture_failed` or `nonce_gap`. No contract redeployment is needed.

| Contract | Round 1 transaction | Stored result | Event |
| --- | --- | --- | --- |
| UpDownRounds | [0x15f6754f…18dda](https://sepolia.basescan.org/tx/0x15f6754f0e8e03a39f882344672a22f0cee851cf7610fe9f616dd6fe3bf18dda) | 4 | Refunded |
| ThresholdPots | [0x05649ccd…b365e](https://sepolia.basescan.org/tx/0x05649ccdb28d74e90bcc43db5ead112f41558d5ac65fd2e01bf1370a476b365e) | 5 | Refunded |

The owner then reported repeated `missed_boundary`, including UpDown round 5336 at timestamp1793756965 and Threshold round5342 at1793757057. This log means the bot abandoned a capture after refreshing the head: `latest.timestamp + 2 !== boundary`. It does not prove the actual contract boundary had already elapsed; the refreshed head may simply have advanced within the preceding two seconds.

## High-severity timing incompatibility

The bot in `packages/foundry/scripts-js/settleBot.js:140` and `:300` assumes the next block arrives two seconds later. Its restart discovery at `:267` treats 32 blocks as roughly a minute. Read-only RPC samples instead show consecutive canonical heights sharing whole-second timestamps, with about five heights per second: e.g.54177320–54177324 all timestamp1793757333. The attached sample preserves a fresh observation.

[Base's official Denim specification](https://docs.base.org/upgrades/denim/200ms-blocks) confirms native 200ms blocks activated on Base Sepolia on October21,2026; EVM `block.timestamp` remains in whole seconds. The bot's two-second lead is therefore approximately ten blocks early, not one block early. Its 32-block recovery horizon covers roughly6.4seconds, not64seconds. Sequential RPC work also makes its initial loop timestamp stale before the refreshed-head guard; the owner RPC latency has not been measured, so no exclusive attribution to provider speed is claimed.

Changing the RPC alone cannot correct these assumptions. Increasing round durations also leaves the exact-boundary submission assumption intact. Preserve exact contract Reading semantics; do not substitute a later price or simply remove the guard.

## First recovery and failed owner rerun

The owner authorized the runtime fix. The bot now supports native 200ms blocks: it prepares capture transactions ahead, prioritizes them over background RPC work, checks a fresh timestamp immediately before each broadcast, and reserves unresolved local nonces. Restart discovery uses elapsed chain time instead of a fixed 32-block assumption. Exact contract Reading semantics remain intact; the reader and both deployed contracts remain usable without redeployment.

The native regression initially failed at the cutoff with the old bot. Validation uses actual local Solidity deployments and the actual CLI, five blocks per whole-second timestamp, 60ms added RPC latency, restart recovery beyond 32 blocks, and three simultaneous captures. Stored results must be UpDown Tie and threshold Yes, with no reverts. See [the test log](logs/settle-bot-denim-smoke.log) and [operating documentation](../settle-bot.md). This controlled fixture establishes local behavior, not public-chain inclusion reliability.

The owner reran this version using Infura and reported repeated capture reverts. Public receipt replay decodes `OutsideBoundary` for the three sampled transactions; neighboring blocks confirm 200ms cadence. The transactions were included 1.0–1.4 seconds after their target boundary. [Receipt/replay evidence](live-capture-reverts.json) also records available UpDown funding of 40000 raw units, so these sampled reverts are not funding failures. This evidence does not identify whether provider latency, broadcast propagation or transaction inclusion caused the delay.

| Capture | Target timestamp | Included timestamp | Delay |
| --- | --- | --- | --- |
| UpDown 5825 cutoff | 1793761855 | 1793761856.400 | 1.400s |
| UpDown 5826 cutoff | 1793761865 | 1793761866.200 | 1.200s |
| UpDown 5825 end | 1793761885 | 1793761886.000 | 1.000s |

## Phase guards and failure stop — live acceptance pending

When `timestampMs` is available and valid, the bot now accepts a fresh head from the final native block before the boundary through the penultimate block of its target second: `[B−200ms, B+800ms)`. It skips the final block, whose successor is already outside the contract boundary. Missing metadata retains the less precise whole-second fallback and is exposed in `ready.nativeTimestampMs`. Every broadcast reports head RPC and submission duration. This adds margin; it cannot guarantee inclusion.

A reverted capture now stops fresh sends with exit status 1 and a `capture_failed` diagnostic, including historical revert decoding when available. Receipt checks run before preparing another capture group. Already broadcast transactions can still mine. Repeated missed-boundary logs remain deduplicated while their Round stays tracked.

[The phase smoke log](logs/settle-bot-phase-smoke.log) records 12 focused passing regressions, legacy CLI coverage, native restart and overlap coverage, and an actual deliberately late local transaction that reverts `OutsideBoundary` and stops the CLI after one submission. The native fixture supplies controlled `timestampMs` metadata to Anvil; it is not a real Denim node. A separate read-only agent review found no further blocker in the phase and failure-stop changes.

Keep the live bot stopped. First run `bash /private/tmp/flashstep-qa-15/run-sepolia-qa-bot.sh --check-rpc` on the owner's machine. This local launcher prompts only for the RPC URL, never a wallet key, and calls `scripts-js/rpcTiming.js` for 12 read-only latest-block samples. Its output omits the URL and reports request duration, metadata and approximate head age; head age includes local clock skew and is not an inclusion guarantee. The script is also usable directly with `SETTLE_RPC_URL` in the environment. No agent has signed on Sepolia. Owner-operated successful captures and normal settlements on both contracts remain necessary; issues #15 and #39 stay open.

## Owner Infura measurement and failed 300ms reproduction

The owner ran the read-only check on the same machine/endpoint. All 12 samples returned native millisecond metadata and advancing heads. Median read duration was 272ms. The initial request took 1742ms; the remaining 11 took 265–342ms. The reported 1742ms p95 is the maximum of this small sample, not an established sustained tail distribution. Approximate head age ranged from 110 to 421ms and includes local clock skew. This measures reads, not broadcast propagation or inclusion.

A temporary copy of the existing native smoke fixture changed only its proxy delay from 60ms to 300ms. The unchanged bot failed `native cutoff capture missing`; [failure log](logs/settle-bot-300ms-smoke.log). The temporary source copy was removed. This demonstrates that the current scheduling implementation is not validated for the owner's measured latency, even without the observed initial 1.742s request. It does not prove an Infura service defect. The passing 60ms suite must not be extrapolated to this endpoint. Keep the live process stopped pending a lower-latency execution path or further scheduling work with matching local validation. No agent sent public-chain transactions.

## Batched execution after the latest owner failure

The latest owner transaction, [UpDown 6015 cutoff](https://sepolia.basescan.org/tx/0xf10d04f9d3600a0a5334f21315d8a27653ee42abb4371e1bcfd3853a4228211f), targeted timestamp1793763755. The log checked head1793763755.200 with a260ms head request and285ms broadcast; the public receipt failed in block54209436 at1793763756.000, one second after the target. The CLI decoded `OutsideBoundary` and stopped, so the failure-stop worked. It did not establish successful capture.

The runtime now batches schedule/account preparation, Round hydration and simultaneous capture submissions, avoiding a redundant head read before submission and serial per-capture HTTP round trips. It validates response ids and locally derived hashes, reserves the entire nonce sequence before sending, and pauses the group on any partial or uncertain response. A shared measured-latency margin guard covers initial native capture groups and individual retries. Startup recovers both contracts' recent Rounds in batches before entering the maintenance loop. HTTP batching is not atomic and cannot guarantee public-chain inclusion.

Final validation is recorded in [focused tests](logs/settle-bot-batch-tests.log), [legacy](logs/settle-bot-batch-legacy.log), [native60ms](logs/settle-bot-batch-native.log), [late fail-stop](logs/settle-bot-batch-late.log), [native300ms restart](logs/settle-bot-batch-300ms.log) and [native300ms overlap](logs/settle-bot-batch-300ms-overlap.log): native restart and three-Round overlap at300ms, legacy scheduling, native60ms and deliberately late fail-stop, plus23 focused regressions. The 300ms fixture keeps the original capture deadlines and allows bounded additional background settlement drain after those deadlines. Independent review identified a retry-margin bypass; it was fixed and covered by a regression. Only public local Anvil keys were used.

For one owner-operated rehearsal, run `bash /private/tmp/flashstep-qa-15/run-sepolia-qa-bot.sh`. The local launcher now remembers newly entered values in macOS Keychain after validation; existing environment values are honored. Agents have not read or written real Keychain credentials. Live successful captures and normal settlements on both contracts remain required; issues #15 and #39 remain open.

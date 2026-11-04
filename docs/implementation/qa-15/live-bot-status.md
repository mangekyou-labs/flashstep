# Live bot rehearsal — 2026-11-04

**Verdict: live acceptance partly passed; Threshold still needs several settled rounds.** The owner started the bot using a dedicated gas-funded wallet. Its submitted Round 1 transactions succeeded, but both emitted `Refunded`, not a normal price-based outcome. Public receipt/result readback is in [live-bot-readback.json](live-bot-readback.json). No agent signed or submitted transactions. Later runs settled five UpDown rounds as Tie and one Threshold round as Yes; see the final section.

> Latest runtime revision: early hydration (12s lead, final sign/hold at 2s) plus a learned send-delay margin passes native restart and three-Round overlap at 300ms simulated RPC latency. The owner may run one supervised rehearsal with the updated launcher; stop and inspect any `capture_failed` or `nonce_gap`. No contract redeployment is needed.

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

## Funded rehearsal and the remaining one-block miss

The owner funded UpDownRounds with 0.2 test USDC. The `approve` transaction [0xef9ab6f…a159](https://sepolia.basescan.org/tx/0xef9ab6f8e48d540de0f2dd74ea7e9e6593c8997e115e029314065710581aa159) succeeded at block54217461; readback then showed `fundingBalance` 200000 with the allowance consumed, so no further top-up is due. ThresholdPots retains 18000 available.

The next supervised run produced one success and one failure stop. UpDown 9440 cutoff [0x7359bc1…f56ec](https://sepolia.basescan.org/tx/0x7359bc1b1742babd12e6fa1552ce9e126a8e414b4b62945d8bbdb403645f56ec) sent on head boundary+0ms (356ms read, 307ms broadcast) and was included at boundary+800ms, the last valid native block. UpDown 9441 was skipped with `insufficient_margin`. UpDown 9442 cutoff [0xe76a10d…f56ec](https://sepolia.basescan.org/tx/0xe76a10dc0af9364269a8ce4b541d2f4d59e60f3e8ef17f53dd4f14f3ad1e3f2d) sent on head boundary+200ms (244ms read, 349ms broadcast, predicted receipt +793ms), missed the +800ms block and was included at boundary+1000ms in block54380786, reverting `OutsideBoundary`. The failure stop worked; no normal settlement resulted. Round 9440 now reads Refunded with its end capture never attempted.

Diagnosis: preparation batches and polling at ~300ms per round trip meant the first ready head could be as late as boundary+200ms, and the old margin (`head + 2×read`) modelled neither the measured send duration nor inclusion jitter after acknowledgement (acknowledged +663ms landed at +800ms; acknowledged +793ms landed at +1000ms). A pre-window send was evaluated and rejected: the local fixture shows inclusion can follow acknowledgement almost immediately, so sending early can land in the previous second and revert.

Fix: hydration now starts 12 seconds before each boundary with signing deferred to a final stage 2 seconds before, so the hold loop can send on the first ready head; re-warming is skipped only after external block polling advances the head. The send decision stays inside the ready window `[B−200ms, B+800ms)` and now requires `head + read + learned send + 100ms < B+800ms`, learning the send duration from each capture broadcast. Predicted-late heads are skipped (`insufficient_margin`) rather than sent to revert. Five new regressions cover the live B+200 skip, the B−200 send, pre-window refusal, and early preparation; all 28 focused tests pass. Evidence: [focused tests](logs/settle-bot-retry-tests.log), [native60ms](logs/settle-bot-retry-native.log), [late fail-stop](logs/settle-bot-retry-late.log), [native300ms restart](logs/settle-bot-retry-300ms.log) and [native300ms overlap](logs/settle-bot-retry-300ms-overlap.log), plus legacy smoke. The margin remains a heuristic; variable provider/sequencer jitter can still miss or revert.

Next: one more supervised owner rehearsal with `bash /private/tmp/flashstep-qa-15/run-sepolia-qa-bot.sh`. Several normal settlements on both contracts, including Tie/Unmatched, are still required; issues #15 and #39 remain open.

## First live settles — owner-run readback recorded

The 0.2 test USDC top-up was consumed by ten first-touch rounds in one run, which stopped at UpDown 10444 with `InsufficientFunding`; no settle had yet recycled surplus. After a further owner top-up of both Campaigns, the owner reran the bot. The run sent at roughly 60% of boundaries, converting predicted-late heads into `insufficient_margin` skips. Confirmed `settle` transactions: UpDown 10508, 10509, 10510, 10512, 10513, 10514, 10515, 10516 and Threshold 10507.

Stored results below come from an owner-run read-only script against the public RPC (the agent's shell was unavailable, so this is single-source owner evidence, internally consistent with the launcher log):

| Round | Stored result | Notes |
| --- | --- | --- |
| UpDown 10509, 10512, 10513, 10515, 10516 | Tie | Start and end Reading prices identical (`2431619644829711020225276722962783928773`); the idle testnet pool TWAP did not move |
| UpDown 10508, 10510, 10514 | Refunded | One boundary capture missing, as logged |
| Threshold 10507 | Yes | End Reading above the 2,000 threshold; opening stakes 1000/1000, no Player stakes |
| UpDown 10438, 10440, 10443 | None (awaiting) | Both captures present; settleable by the bot on a later restart |

Funding after the run: UpDown 1560000 available / 620000 reserved; Threshold 1014000 / 6000.

The run stopped on UpDown 10544: the earliest head (boundary−200ms) saw a latency spike (430ms read, 419ms broadcast) and inclusion missed the final +800ms block, reverting `OutsideBoundary`. One revert in about 35 submissions; the guarded margin cannot guarantee inclusion under provider/sequencer spikes.

Assessment against #15: UpDown has several bot-settled rounds including Ties; Threshold has one normal Yes settlement and still needs several settled rounds. Player stake/claim evidence and the hosted Playwright pass remain outstanding. Issues #15 and #39 remain open.

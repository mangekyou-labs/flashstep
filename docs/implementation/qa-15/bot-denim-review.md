# Bot timing fix — issue #39

The original live rehearsal refunded both Round 1 transactions and later reported missed captures. The owner authorized the bot runtime fix; no contracts, generated deployment manifests or frontend bundle changed.

## Independent review

A separate read-only QA agent reviewed `settleBot.js`, `boundaryScheduler.js` and `transactionSender.js`. Its initial blockers were local nonce reuse after an uncertain broadcast and retries using a stale timestamp after capture preemption. Both were corrected. A later edge involving expired lower-nonce captures with higher queued transactions was corrected by retaining the unresolved nonce and pausing new work. The final read-only review found no remaining blocker, subject to final smoke results.

The actual native restart fixture additionally caught partial discovery: the scheduler held maintenance after caching UpDown but before caching Threshold. Near-deadline preparation now refreshes both current schedules and hydrates known uncached Rounds before grouping captures. Initial discovery of stopped Rounds still uses the existing both-contract recent-event scan.

## Validation

- [Local smoke log](logs/settle-bot-denim-smoke.log): original two-second behavior, restart and pending recovery, request pacing, invalid configuration; native 200ms cadence with repeated whole-second timestamps, 60ms RPC latency, stopped-Campaign restart beyond 32 blocks; three simultaneous captures and three stored normal settlements per contract. All passed. Solidity artifacts were already compiled; no Solidity changed.
- [Recovery regressions](logs/settle-bot-recovery-tests.log): nine passed, zero failed. Includes fresh expiry checks, per-capture timestamp rechecks, ambiguous acceptance, cross-contract cache hydration, local nonce reservation, definite rejection, legacy cadence and expired/rejected lower-nonce gaps. The ninth regression adds the equivalent conservative queue protection for definite rejection on a retry.
- JavaScript syntax, launcher Bash syntax and `git diff --check` passed.

All local transactions use a public Anvil account against isolated local deployments. The native fixture models five canonical heights per EVM timestamp second; it is not a real Denim node or proof of public-chain inclusion. The final live acceptance gate remains owner-operated captures and normal settlements on both deployed Sepolia contracts. Issue #15 and #39 stay open; other ETHSKILLS QA/CROPS findings remain tracked separately. No pilot-ready or security-audit claim is made.

## Failed live rerun and phase correction

The owner's Infura run after the initial fix still reverted. Three sampled receipts replay as `OutsideBoundary`, with inclusion 1.0–1.4 seconds after the target; see [live evidence](live-capture-reverts.json). Provider fault is not established. The fresh-head guard previously allowed the final block of a target second and could not use the last preceding block.

The correction validates native `timestampMs` and uses the phase interval `[B−200ms, B+800ms)`. It also stops on an observed capture revert and checks capture receipts before preparing further work. Independent read-only review found no new blockers; its own run of the 12 focused tests passed.

[Full phase validation](logs/settle-bot-phase-smoke.log) passes legacy, native restart and three-capture overlap scenarios. The added negative case holds a real signed local capture past its boundary, mines the revert and verifies exit status 1, decoded `OutsideBoundary` and only one submitted capture. The native test proxy supplies controlled matching millisecond metadata to Anvil. These are local proofs of guards and failure handling, not proof of live inclusion. The next owner action is read-only RPC timing measurement, not an unattended paid retry.

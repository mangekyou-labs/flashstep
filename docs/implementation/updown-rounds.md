# One up/down Round in ETH — issue #3

This is the first contract slice of [issue #3](https://github.com/mangekyou-labs/flashstep/issues/3), under the [paid fast rounds spec](../../.scratch/paid-fast-rounds/spec.md). `UpDownRounds` sits beside the untouched challenge contract. One owner-funded Round has a private Up/Down share book, exact-share buys, time-derived phases, TWAP settlement and pull claims. Selling, repeating Campaigns, owner withdrawals and settings changes belong to #4; outage refunds and expiry belong to #6; the page belongs to #8. The contract is a build slice, not a complete Campaign deployment.

## Interface and accounting

- Deploy `UpDownRounds(payer, reader)` with a deployed `BasePoolReader` vetted for the payer's pool. The reader is immutable. The deployer receives no special authority unless named as payer.
- The owner calls `fund()` with ETH, then `seedRound(seed, stakeCap, tradingSeconds, windowSeconds)` once. Round id is 1. Other ids revert `UnknownRound`. Funding not assigned to the Round remains in `fundingBalance`.
- ETH amounts, including quotes and the cumulative Stake cap, are in wei. Shares have 18 decimals. One whole winning share pays 0.01 ETH (`PAYOUT`). The maximum accepted seed and Stake cap are both `1e30` wei. Seed minimum is 0.01 ETH, providing at least one whole share per side before the lock. Stake cap minimum is 1 wei. These are implementation arithmetic bounds, not economic recommendations for a pool.
- Seeded ETH backs `seed × 1e18 / PAYOUT` shares on each outcome. Ten percent of each share book is an opening lock, used only in chance calculations, with no address able to redeem it. Players can buy only the remaining reserves. Even if every available share on the winning side is sold, total Player payouts are at most 90% of seeded ETH, before counting buy receipts. This intentionally retains the challenge's reserve-limited book; it does not mint shares against new buy receipts.
- `quote(roundId, side, exactShares)` uses the challenge's average before/after sold-share chance, with symmetric opening chance 50 cents. It charges the average chance times shares times the Payout, rounded upward to wei. Example: a 1 ETH seed locks 10 shares per side; buying 20 Up shares moves chance from 1/2 to 3/4 and costs 0.125 ETH. Upward rounding prevents free dust buys. This is the documented Speedrun average formula, not the integral-pricing experiment in the original working checkout.
- `buy(roundId, side, exactShares, maxCost)` requires the exact current quote as `msg.value`, and refuses a quote exceeding `maxCost`. The cutoff is the transaction deadline. A stale transaction may fail even when chance falls, because payment must match the fresh quote. The page ticket must pass a real bound from the quote; no page is added here. The cap counts all earlier paid buys, including buys of the other outcome. The current owner cannot buy.
- `positionOf` returns Up shares, Down shares, paid ETH and whether a positive claim was consumed. `claimable` quotes the actual next transfer. A loser, a second claim or a winning dust position rounded below one wei pays zero. Unsettled `claim` reverts. Positive claims update state before sending ETH with `call`, behind `nonReentrant`. A recipient that refuses ETH retains its own claim and does not block other Players. Claims never expire.
- A Tie refunds exactly the paid buys. With no selling in this slice, this equals net paid; #4 must extend that accounting to sell proceeds. Winning shares redeem with downward rounding to wei, and any remainder remains with the Round for #4's owner-withdrawal accounting.

## Time and captured Readings

`phase(1)` changes Trading → Window → AwaitingSettlement from timestamps alone; it becomes Settled after successful settlement. There is no Oracle and no `report`. The spec ranges are Trading 5–30 seconds and Window 1–30 seconds. The currently supported subset is even Trading 6–30 seconds and even Window 2–30 seconds. `BLOCK_INTERVAL = 2` encodes the supported Base cadence; `seedRound` rejects incompatible durations with `InvalidConfiguration` before accepting a Round or any Player stake. Durations are never rounded. Seeding occurs in a block, so adding whole cadence intervals preserves alignment even when the chain timestamps themselves are odd. This restriction is the issue #3 review decision: accepting a setting whose exact boundary cannot exist strands Player funds. A future cadence change requires an explicit contract/configuration decision and tests against that cadence; #12 deployment validation must verify the target chain still matches the supported interval.

Anyone can call `captureBoundary(1)` at exactly the cutoff and exactly the Window end. It calls the real reader's `capture`, retains the first successful block id for each endpoint, and does not replace it on repeated calls. Post-settlement captures refuse. Anyone can then call `settle(1)` at or after the Window end; delayed settlement loads both endpoints with `BasePoolReader.read`. Both full Readings are stored in `round(1)` and the result is Up if end price is higher, Down if lower, Tie if equal. A later pool price cannot change the result.

A transaction must exist at each boundary. A payer-funded settle bot (#11) must capture both boundaries as well as call settle; just calling settle late is insufficient. Winning Players can also settle to unlock their claims, but no caller fee is paid, so relying on them alone is not a liveness guarantee. Missing captures refuse with `NoValidReading`; there is never a latest-price substitute. As agreed for the reader in #2, missed boundaries must eventually refund. That recovery and the 24-hour nobody-settled path are explicitly #6 and are not shipped here. Until then, a missed boundary leaves funds awaiting settlement.

## Owner powers and public data

The owner can fund the balance, choose the one seed/cap/timings before trading, transfer ownership, and renounce ownership. Funding cannot take a Player's ETH. Seeding commits the chosen settings and consumes only prefunded ETH. Ownership transfer changes who may fund and seed and who is excluded from buying; it does not change any existing position or Reading. Renouncing or losing the owner key prevents further owner actions. Existing buys, boundary captures, settlement and claims still work without that key. No owner function reports a result, edits a Round, pauses Players, upgrades the contract, sweeps claims or withdraws Player funds. Owner withdrawal of leftovers is deferred to #4, so remaining ETH is retained in this slice.

Anyone can read, fork and call the contracts directly without a hosted page or API. Running future automated captures still needs a funded transaction sender. Positions, paid amounts, results, captured blocks and event history are permanently public onchain. This implementation and its tests are not an independent audit or a standing safety guarantee. Forced ETH donations can add custody balance without a corresponding recorded funding transaction; the accounting search below models funded deposits, buys and claims, not forced donations.

## Validation

Run from `packages/foundry`:

```sh
forge test --match-path 'test/rounds/*.sol' -vv
FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true forge test --match-contract UpDownRoundsInvariantTest -vv
BASE_RPC_URL=https://mainnet.base.org forge test --match-contract UpDownRoundsForkTest -vv
forge fmt --check contracts/UpDownRounds.sol test/rounds
```

The Round suites have 25 unique tests: 14 deterministic, two adversarial callback tests, six fuzz/boundary tests (one uses 256 generated cases), two handler invariants and one pinned-fork integration. Without `BASE_RPC_URL` the fork explicitly skips. Fixtures are shared without inheriting and repeating unit tests.

The seed/cap fuzzer bounds the entire supported seed `[1e16,1e30]` and cap `[1,1e30]` domains, bounds shares to actual reserves, and checks ETH conservation through accepted buys and claims, or unchanged custody on cap refusal. Explicit cases classify the minimum, adjacent valid value, exact maximum and first invalid value; reserve exhaustion and a cumulative cap reached exactly followed by one additional wei are separate tests. Boundary capture tests ensure the retained endpoint cannot be overwritten or replaced after settlement. Callback tests show claimable is already zero during payment, claim and settle reentry both fail at the guard, and a reverting recipient can retry while others claim.

The handler targets buy, boundary advance, settle and claim across three funded ordinary addresses. Ghost stakes and paid claims come from observed Player balance changes. Its equality is **ETH held = seeded ETH + stakes − paid claims**, checked after randomized sequences. A second invariant checks all outstanding claims are backed. First buys cover opposite outcomes and nonzero redeemable share sizes, and boundary advance waits for two successful buys. Counters distinguish successful buys and positive payouts from action calls that become no-ops after the Round finishes. Runs use `fail_on_revert=true`; calls/reverts statistics must be inspected, not merely a green status.

Red/green evidence: the first phase test failed to compile because `UpDownRounds` did not exist, then passed with the contract. Review regressions failed because a repeated capture overwrote the first block and a post-settlement capture was accepted; both passed after endpoint immutability was enforced. The initial handler found that fixture addresses `0xA/0xB/0xC` were precompiles rejecting ETH; ordinary Player addresses fixed the fixture before the final search. The fork rolls the actual Base pool from block 35,000,000 to cutoff block 35,000,005 and end block 35,000,007, keeps the local contract/reader persistent, and settles at block 35,000,010. It checks sane historical Readings and actual Player receipts against the observed result.

Final recorded invariant search: each property ran 128 runs × 100 depth = 12,800 calls, with zero reverts. Conservation selectors recorded 3,200 advance / 3,182 buy / 3,229 claim / 3,189 settle calls; the final sequence had two successful buys and one paid claim. The backing property recorded 3,220 / 3,128 / 3,184 / 3,268 respectively, with four successful buys and two paid claims in its final sequence. These counters include phase-inapplicable no-ops; the successful-action counters confirm actual trades and transfers.


## Review corrections and static analysis

The integrated pre-review run reported 65 passes, but the Round fork test had an unconditional `return` after the optional skip branch. That run did **not** exercise Round fork integration. The branch now contains explicit braces, and every conditional return in the Round suites was inspected for the same error. The corrected `-vvvv` RPC run used 3,001,050 gas and traced real pool captures at blocks 35,000,005 and 35,000,007, settlement at 35,000,010, and a Tie refund of 0.005119047619047620 ETH. This supersedes the earlier fork-validation claim. The independent reader fork tests were unaffected. The final combined reader/Round run passed **67 tests, zero failures, zero skips**, including both real pinned forks and both strict 128 × 100 invariants. The final format check passed.

The new duration rejection regression failed before the contract check (`next call did not revert as expected`), then passed. It rejects every odd duration from 1 through 31, including former accepted configurations 5/4 and 10/1, and confirms a refused configuration leaves funding available for a valid Round. The accepted minimum/maximum combinations 6/2, 6/30, 30/2 and 30/30 progress in actual two-second test blocks, capture both exact boundaries and settle. The test uses a local simulated clock because Solidity may cache `block.timestamp` across Foundry cheatcode calls inside a loop.

Slither analyzed 24 contracts with 102 detectors and reported 40 findings in the integration scan. It reported no reentrancy finding. New Round findings are triaged as follows; this is static-analysis triage, not an audit.

| Detector | Decision |
| --- | --- |
| strict equality on cutoff / timestamp comparisons | Intentional: exact scheduled endpoints are the reader contract's boundary requirement. Cadence-incompatible durations now reject onchain. A missed block or missing capture can still prevent settlement; #6 must provide recovery rather than substitute a later price. |
| strict equality on `Result.None` in `claim` | False positive: this is a discrete enum sentinel for unsettled state, not a timestamp or ETH balance equality. |
| low-level call in `claim` | Intentional pull payment using checked `call`, state consumed before interaction, and `nonReentrant`; callback and rejecting-recipient tests exercise it. |
| `i_reader` naming | Accepted project immutable naming convention. |

Inherited reader findings (TickMath arithmetic/constants, uninitialized-local, discarded low word of `mul512`, timestamp sentinels, complexity and naming) are unchanged and covered in the [reader triage](base-readings.md#slither-triage). Challenge-interface naming findings are outside this slice.

# Up/down Campaigns — issue #4

[Issue #4](https://github.com/mangekyou-labs/flashstep/issues/4) extends the [issue #3 Round](updown-rounds.md) using the [paid fast rounds spec](../../.scratch/paid-fast-rounds/spec.md). The original constructor, first `seedRound`, exact-share buys, reader captures and pull claims remain compatible. This contract still requires the missed-capture/expiry recovery in #6 before complete Campaign operation.

## Trading and exact liabilities

`sell(roundId, side, shares, minProceeds)` accepts owned shares only during Trading and transfers the downward-rounded `quoteSell` amount. It uses the same average before/after chance formula as buying. The caller supplies a real minimum proceeds; a stale price below that minimum reverts. Page #8 must quote this method and pass a user-approved minimum to `sell`, rather than an unconditional zero. No Campaign page or generated deployment ABI is added here.

The Stake cap counts cumulative gross purchases in a Round, across both outcomes. Selling never restores that allowance. A Position keeps cumulative `bought` and cumulative `proceeds`; its Tie refund is `max(bought - proceeds, 0)`. The floor is applied to those cumulative totals after every trade. A profitable sale therefore carries credit through later purchases; flooring each sale independently and adding subsequent buys would over-refund that Player. A Tie pays only this refund, never a share payout in addition.

Average before/after pricing can yield a profit after another Player trades. Consequently the sum of independently floored Tie refunds cannot be inferred from the pot's net receipts. Every successful buy and sell checks all three possible outcome liabilities against that Round's own collateral before a sell sends ETH. A quote describes price; execution can still refuse with `InsufficientReserve` to preserve backing. An overlapping Round's seed or claims never subsidize a profitable sale.

For Up and Down, the running liability is the sum of each Position's individually rounded payout. Updating it uses the difference between the Position's payout before and after the trade. This avoids an aggregate-rounding remainder that nobody can claim. Settlement releases exactly `collateral - actual winning liability` to owner funding and retains only actual remaining claims. Each claim reduces both Round collateral and global `reservedBalance`. Every payment uses checked `call`, effects before interaction, and `nonReentrant`; a rejecting recipient rolls back its own operation.

## Lazy schedule and settings

`seedRound` starts the Campaign at the transaction timestamp and materializes Round 1. Later Round starts follow the schedule without an open transaction. `currentRound` derives the trading id from time; a following Round can trade while earlier Windows remain unresolved. Each book has its own collateral, shares, cap, reader, captured endpoints and result. Idle Rounds consume no seed. The first successful buy or boundary capture materializes a scheduled book from available owner funding. If funding is insufficient, that operation reverts without taking a Player payment. A failed settlement/capture also rolls back any attempted materialization. There is no loop over all skipped Rounds.

`setCampaignSettings(seed, cap, tradingSeconds, windowSeconds, endTime, reader)` queues an epoch at the current Round's cutoff. Multiple changes within that Trading phase replace the pending epoch. Later changes append epochs, found by binary search. Existing materialized and lazy Rounds keep the correct original snapshot. The constructor's `i_reader` is the initial reader; every Round stores the reader used for its own captures and settlement. A reader change is a trust decision requiring the same pool/reader vetting as initial setup.

`endTime` is an exclusive limit on new Round **starts**. A Round that starts before it finishes its full Trading phase and Window, even if the end falls inside Trading. `currentRound` becomes zero after that final Trading cutoff. Settings require a future next start and cannot restart an already ended Campaign.

The #3 Base cadence decision remains explicit: supported Trading durations are even values 6–30 seconds and Window durations even values 2–30 seconds. The broader spec bounds 5–30 and 1–30 do not override exact captures on two-second blocks. Tests classify Trading 4/5/30/31 and Window 0/1/30/31; 5 and 1 reject as cadence-incompatible, 30 accepts, 4/0/31 reject as outside bounds. Durations are never rounded. The bound fuzzers cover both supported and refused durations and the complete cap range `[1,1e30]`. Missing boundary captures still strand settlement until #6; there is no latest-price substitution.

`stopCampaign` is irreversible. It stops after the current scheduled Trading cutoff, including when that scheduled Round has had no trade yet. That current book remains available until cutoff; no subsequent id can start. Earlier books still capture, settle and pay. Calling stop before initialization prevents the first Round from starting. Settings, end extension and another `seedRound` cannot resume a stopped Campaign.

## Owner powers

The owner can:

- Fund the Campaign and choose the first seed, cap and durations with `seedRound` once.
- Change next-Round seed, cap, Trading duration, Window duration, exclusive end time and reader. Existing Round settings, stakes and captured Readings are immutable.
- Stop new starts after the current Trading phase. This cannot interrupt that Round's Trading or an existing Window, settlement or claim.
- Withdraw `fundingBalance`: uncommitted funding plus surplus released by completed settlement. Active seed is locked owner liquidity, and is excluded from this withdrawable amount along with every Player stake and claim. Withdrawing uncommitted funds can prevent a future lazy Round from materializing; no funding is reserved for all future schedule slots.
- Transfer or renounce ownership through inherited Ownable. The current owner cannot buy. Transfer changes future authority and the excluded buyer; losing or renouncing the key prevents future owner actions, while permissionless captures, settlement and claims continue.

There is no owner result override, claim sweep, upgrade, edit to a live Round or withdrawal of reserved collateral. The owner could configure a malicious next reader; onchain access control does not validate its economic integrity. Positions, cumulative paid/proceeds, share books, readings and all transactions are public onchain.

## Validation and equality accounting

Run from `packages/foundry`:

```sh
FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true BASE_RPC_URL=https://mainnet.base.org forge test --no-match-path test/PredictionMarket.t.sol -vv
forge fmt --check contracts/UpDownRounds.sol test/rounds
uvx --from slither-analyzer slither .
```

Red/green slices covered quoted selling/net Tie refunds, protected withdrawal, automatic overlapping books, next-Round settings and irreversible stop. A further regression first failed with `currentRound == 0` inside the final already scheduled Trading phase; deriving end eligibility from the Round start fixed it. Tests additionally preserve profit credit across later buys, reject a sell above ownership or after cutoff, enforce cumulative cap after sell, snapshot replacement reader/settings across lazy epochs, and skip 100,000 idle slots without allocating their seeds. Adversarial recipient tests cover rolled-back sell/withdraw transfers, effects visible during callbacks, blocked reentry, and the existing rejecting-claim recipient behavior.

The Campaign handler uses three ordinary Players, independent balance-observed buy/sell/claim/withdraw ledgers and eight actions: buy, sell, advance/capture, settle, claim, configure, stop and withdraw. Each run begins with actual buys/sells in two overlapping books. Unexpected errors fail; only identified cap/backing refusals are caught, with unchanged Player balances required. Timing advances visit every supported two-second boundary. The final drain progresses beyond the latest possible Window, settles every materialized book, compares every unpaid Tie claim with independently observed cumulative buy/sell amounts, withdraws all owner funding and claims every Player payout, leaving zero ETH.

Before settlement, the truthful live equality is **held = unresolved escrow + settled Player claims + owner withdrawable liquidity**. Unresolved escrow includes locked seed and stakes. Calling the whole seed a Player claim or immediately withdrawable owner liquidity would be false. After all materialized books settle, the literal ticket equality holds: **held = owed to Players + owner's withdrawable liquidity**. The terminal drain checks that no unaccounted rounding remainder stays trapped. A separate invariant reconciles all custody to observed funding, stakes, sell payments, claims and withdrawals. Forced ETH donations are outside these ledgers and can increase held ETH without creating a recorded liability.

The final scoped run passed **87 reader/Round tests, zero failures, zero skips**, including both real pinned Base forks. Each of the two Campaign properties ran 128 × 100 = 12,800 calls with zero reverts. Source/destination action calls were advance 1,611, buy 1,578, claim 1,542, configure 1,603, sell 1,640, settle 1,635, stop 1,564 and withdraw 1,627; its final sequence executed three buys, two sells, one positive claim and two settlements. Live-partition action calls were 1,616 / 1,600 / 1,623 / 1,562 / 1,620 / 1,549 / 1,622 / 1,608 in the same order; its final sequence executed two buys, two sells, one positive claim and two settlements. Both final sequences recorded zero expected refusals; other searches exercised the allowed backing/cap refusal branch. Phase-inapplicable calls can be no-ops, so successful-action counters and final zero-custody drains are checked separately. Format and diff whitespace checks passed.

An unrestricted `forge test` also ran: **88 passed and 41 failed**. Every failure belongs to the unchanged original `PredictionMarketTest` challenge skeleton, whose implementation is still deliberately incomplete; the scoped reader/Campaign suite is green. Neither that contract nor its tests were changed by #4. This deliverable does not claim that the whole repository suite is green.

## Static analysis

The unfiltered Slither scan analyzed 24 contracts with 102 detectors and reported 113 findings: 1 high, 25 medium, 22 low, 63 informational and 2 optimization. This full dependency scan is different from #3's filtered 40-finding integration report. No reentrancy finding was reported. All high and medium findings were inspected:

| Finding | Triage |
| --- | --- |
| High `incorrect-exp`, OpenZeppelin `Math.mulDiv` | False positive: `(3 * denominator) ^ 2` is the library's intentional bitwise-XOR seed for modular inverse iteration. Changing it to exponentiation would break the algorithm. Installed dependency source was inspected. |
| Medium `divide-before-multiply`, OpenZeppelin Math (9 findings) | Intentional full-precision normalization, modular inverse refinement and Euclidean inverse arithmetic. These divisions are part of the library algorithm, not lost market precision. Dependency unchanged. |
| Medium `divide-before-multiply`, TickMath | Intentional fixed-point normalization followed by reciprocal; unchanged reader dependency, covered by reader round-trip/extreme-tick tests. |
| Medium `divide-before-multiply`, `currentRound` | Intentional floor to a discrete schedule slot followed by multiplication to recover that slot's start. Rounding down is the required behavior; end-inside-Trading regression exercises it. |
| Medium `incorrect-equality` (10 findings) | Discrete `Result.None`/Tie/Up and zero-id sentinels, exact pending epoch id comparison, reader missing-reading sentinel, and exact boundary timestamps. The first groups are intentional discrete state comparisons. Exact boundaries are required by captured Readings, with the documented cadence rejection and missing-capture limitation. |
| Medium `locked-ether`, original `PredictionMarket` | Inherited challenge skeleton has payable stubs without withdrawals. It is untouched and separate from UpDownRounds; changing challenge steps is outside #4. The Campaign has tested sell, pull claim and owner funding withdrawal paths. |
| Medium `uninitialized-local`, `BasePoolReader.capture.cumulatives` | Assigned on successful pool `observe`; catch reverts before any read. No uninitialized value reaches pricing. The Campaign's own schedule index is now initialized explicitly. |
| Medium `unused-return`, reader `mul512` (2 findings) | Only the high word is needed to detect overflow before the later full-precision operation; discarding the low word is intentional. Both readers are unchanged. |

Low/informational findings are timestamp use for schedule phases, checked low-level payment calls, inherited TickMath/Math assembly/constants/complexity, naming and style. See [reader triage](base-readings.md#slither-triage) for unchanged reader reasoning. This triage and the local tests are not an independent audit. No external feedback or deployment transaction was sent.

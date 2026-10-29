# Threshold Pots — issue #5

[Issue #5](https://github.com/mangekyou-labs/flashstep/issues/5) adds `ThresholdPots`, an ETH pari-mutuel Pot for each scheduled Round. It uses the existing `BasePoolReader` and `MarketCapReader` end Reading. Price and market cap support a fixed threshold: above is Yes, below is No, and equality is Tie. There is no relative-threshold rule or relative-rule arithmetic in this implementation.

## Stakes and settlement

The payer funds the Campaign, then calls `seedRound(CampaignSettings)` once. `openingStake` is the amount allocated to **each** side. It is a normal stake owned by that Round's snapshotted payer, with the same payout or refund as any Player stake. The Opening stake can be zero. `stake(roundId, side)` accepts positive ETH only during Trading; cumulative Player payments across both sides consume the Stake cap. Automatic Opening stakes do not consume that cap. There is no selling or fee.

Both sides are fixed at Trading cutoff. If either side is empty, settlement after the Window produces Unmatched without a Reading; all stakes are refundable. Otherwise, anyone must call `captureBoundary` at exactly `windowEnd`, then call `settle`. Settlement uses that pinned block's historical TWAP Reading. Price uses `BasePoolReader.read`; market cap uses `MarketCapReader.readMarketCap`, including its completed-block requirement and historical supply semantics. Unsupported supply modes and mismatched price/market-cap readers are rejected when configuring a market-cap Round. No spot or latest-price fallback is used. A missing endpoint capture still prevents matched settlement; expiry and missed-capture recovery belong to #6.

A winning Position receives `Math.mulDiv(stake, pot, winningTotal)`, rounded down once over its aggregate winning stake. Tie and Unmatched refund the Position's Yes plus No stakes. `claimable` and `claim` use the same amount. A repeated claim returns zero. Pull claims and funding/dust withdrawals use checks-effects-interactions, checked ETH calls and `nonReentrant`; a rejecting recipient rolls back only its own attempted operation and can retry.

## Custody and dust

`fundingBalance` is uncommitted Campaign prefunding. `reservedBalance` is the sum of materialized Round collateral. Before settlement that collateral is unresolved escrow, not a claim liability. After settlement it contains unpaid claims plus unresolved rounding reserve. The contract does not enumerate Players or claim that this entire remainder is dust.

Each winning claim consumes that Position's winning stake from `remainingWinningStake`, including when a computed payout is zero. Only after the last winning Position claims is the residual collateral proven to be dust. That amount becomes `dustCredit[round.payer]`, is recorded in `round.dustReleased` and `totalDustCredit`, and leaves `reservedBalance`. `withdrawDust` pays the credited beneficiary. Ownership transfer cannot redirect a materialized Round's Opening stake or dust. A losing or untouched claimant is never swept. Dust release therefore waits for every winner to claim; there is no claim expiry in this ticket.

For ordinary transfers, live custody is **held = funding + unresolved Round escrow + settled unpaid claims + unresolved rounding reserve + released dust credits**. After all materialized books settle and uncommitted funding is withdrawn, it is literally **held = unpaid claims + tracked dust reserve/credits**. The handler independently sums actor claims and calculates the reserve; it does not relabel all retained collateral as dust. Its final drain claims every actor and withdraws all dust, checking zero stranded ETH. Forced ETH donations can increase held ETH without creating a recorded liability.

## Schedule and authority

The lazy schedule matches `UpDownRounds`: starts are derived from time, a new Trading Round overlaps previous Windows, and idle slots consume no Opening stake. The first successful stake, capture or settlement materializes a book from available funding. Insufficient prefunding rolls back that operation and any Player payment. There is no loop over skipped slots.

`setCampaignSettings` applies at the current Trading cutoff. Repeated edits before that cutoff replace the pending epoch. Existing Round thresholds, readers, caps, durations and Opening amounts retain their scheduled snapshots. `endTime` is an exclusive bound on starts; a Round starting before it completes its full Trading and Window. `stopCampaign` irreversibly prevents starts after the current scheduled Trading Round. Earlier captures, settlement and claims remain available. Stopping before initialization prevents seeding.

The owner can fund, seed, schedule future settings, stop, withdraw uncommitted funding, transfer ownership or renounce it. Withdrawing prefunding can prevent future lazy materialization. A materialized Round's payer remains its beneficiary; an unmaterialized book allocates its Opening stake to the owner when it materializes. The constructor validates and exposes the initial `i_reader` for consistency with the existing Campaign API; operational captures use each Round's snapshotted settings reader. Choosing a replacement reader is a payer trust decision: code existence checks do not establish its economic integrity. Stakes, results and positions are public onchain. There is no owner result override, claim sweep, live-book edit or reserved-fund withdrawal.

## Accepted bounds and verification

The fixed threshold accepts `[1, uint256.max]` in Reading units (1e36 quote-token units for price, supply-adjusted for market cap). Opening stake per side accepts `[0, 1e30]` wei, and Stake cap `[1, 1e30]` wei. Trading accepts even durations 6–30 seconds and Window even durations 2–30 seconds, preserving the existing exact two-second Base capture cadence. Odd spec minima 5 and 1 are rejected rather than rounded. The configured end must permit a next start when changing settings.

Tests exercise nearest valid values, exact bounds and first representable out-of-range values, including threshold zero/one/max (there is no representable value beyond uint256.max), Opening zero/one/max/max+1, and cap zero/one/max/max+1. Bound fuzzing covers the complete accepted stake, Opening and threshold domains. Exact threshold and one unit on either side are tested for both metrics using real readers. Deterministic tests cover cumulative cap, overlapping books, lazy funding, final-round completion, Tie/Unmatched, missing capture, rounding and beneficiary preservation. Supplemental tests exercise actual payment callbacks, rejecting-recipient retry and historical market-cap supply.

Run from `packages/foundry`:

```sh
FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 FOUNDRY_INVARIANT_FAIL_ON_REVERT=true BASE_RPC_URL=https://mainnet.base.org forge test --match-path 'test/threshold/*' -vv
forge fmt --check contracts/ThresholdPots.sol test/threshold
```

The final scoped run passed **26 tests, zero failures, zero skips**, including the real pinned Base pool fork (blocks 35,000,000, endpoint 35,000,007 and settlement 35,000,010). Full-domain payout fuzzing ran 257 cases and near-Reading fuzzing 256 cases. The strict handler ran 128 × 100 = 12,800 calls with zero reverts and zero discards. Its selector counts were advance 2,084; claim 2,123; settle 2,150; stake 2,066; dust withdrawal 2,135; funding withdrawal 2,242. Every sequence also requires positive stakes, settlements and claims and completes the final zero-custody drain. Format and whitespace checks passed.

Pinned Base fork tests require a reachable RPC. This implementation does not deploy contracts or alter generated deployment artifacts. These are scoped ThresholdPots results; combined upstream-suite validation and static-analysis triage are separate checks.

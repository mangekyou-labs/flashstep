# Outage refunds and unsettled expiry

Implements issue #6 for `UpDownRounds` and `ThresholdPots`, building on the existing Campaign schedule and block-pinned Reading modules. Challenge contracts and tests are unchanged.

## Decisions

- A missing required Reading makes an unresolved Round refundable at `windowEnd + 60 seconds`, inclusive. The constant is `READING_GRACE_PERIOD`; the ticket did not prescribe a numeric grace period. Both timestamp boundaries and actual reader availability are checked, including historical supply availability for Market Cap. A later spot price or captured block never substitutes for the scheduled endpoint.
- Valid Readings remain settleable throughout the grace period and until `windowEnd + 24 hours`. At that inclusive expiry, any unresolved Round refunds even if its eventual winning outcome is known. Already settled outcomes never change and their claims never expire.
- `phase` and `claimable` compute timeout eligibility without a transaction. The stored `round().result` remains `None` until permissionless `claim` or `settle` persists `Refunded`. Allowing `settle` to persist a refund follows issue #6's permissionless refund goal; it deliberately supersedes the older creator-feed wording that settlement reverts after expiry.
- Up/Down Players recover cumulative buys minus cumulative sell proceeds, floored at zero. The payer's full seeded liquidity becomes a separate pull credit through `refundCredit`, `totalRefundCredit`, and `withdrawRefund`. It follows the original materialization payer through ownership transfer or renunciation. Renunciation requires withdrawing uncommitted funding first, consistent with Threshold's existing protection.
- Full seed conservation requires `collateral >= seededLiquidity + refundLiability` throughout trading, alongside either winning-side liability. Sells whose proceeds would consume seed to fund another Player's refund now revert `InsufficientReserve`. This also guarantees Tie refunds are fully backed. The earlier profitable-sell regression is updated to assert this stricter reserve requirement. Quotes remain mathematical estimates; execution enforces backing.
- Threshold refunds return each address's Yes and No stakes, including the original payer's Opening position. Refunds release no rounding dust.
- Never-materialized expired scheduled slots have no escrow. `claim` returns zero and `settle` rejects them without spending Campaign prefunding. A computed Refunded phase on an idle slot does not create a payout.
- Claims and payer withdrawals use checks/effects/interactions with reentrancy protection. Rejected transfers roll back refund persistence and credits; they do not block other recipients.

## Verification

Vertical red/green slices first added a missing-end mock-observation test to each contract. Each failed against the preceding implementation with `NoValidReading`, then passed after that contract's refund path was implemented. Direct tests then covered the grace and expiry timestamps at minus one, exactly, and plus one second; expiry claim without settlement; available Readings at grace; settled and refunded claims years later; repeated claims; net sells; original payer ownership transfer/renunciation; unavailable historical supply; and idle-slot prefunding protection.

An initial broad non-challenge run (`FOUNDRY_INVARIANT_RUNS=16 FOUNDRY_INVARIANT_DEPTH=40 forge test --no-match-path 'test/PredictionMarket.t.sol' -vv`) produced 129 passing tests, three fork skips without an RPC, and one failing old profitable-sell expectation. That expectation now asserts the explicit full-seed backing requirement described above.

Both handler suites now include outages and 24-hour jumps. They reconcile observed deposits and payments with unresolved escrow, outstanding claims, funding, and payer credits using equality. A strict run exposed the handlers' old assumption that only `settle` finalized books; claim-triggered refund finalization is now included in their settlement/refund counters. Handler call/revert tables remain enabled.

The added Base fork tests pin block 35,000,000, intentionally miss the scheduled endpoint at block 35,000,007, and capture only a later Reading. Both prove the missed block remains unavailable and all Player/payer funds refund at the deadline without using that later Reading. Existing successful fork settlements remain intact.

Additional security regressions cover rejected claim-triggered refunds, independent recipient progress, rejected payer withdrawals preserving credits, zeroed credits during payment, blocked withdrawal reentry, and once-only payer payment.

Final scoped command/results are recorded below after validation.

Final scoped validation:

```sh
FOUNDRY_INVARIANT_RUNS=32 FOUNDRY_INVARIANT_DEPTH=60 \
FOUNDRY_INVARIANT_FAIL_ON_REVERT=true BASE_RPC_URL=https://mainnet.base.org \
forge test --match-path 'test/{rounds,threshold}/*' -vv
```

Result: **95 passed, zero failed, zero skipped**, including all four real Base fork tests and both handler suites. The strict handlers reported zero unexpected reverts. `forge fmt --check` and `git diff --check` also pass. Root integration runs the combined non-challenge suite and static analysis after merge; no deployment was performed.

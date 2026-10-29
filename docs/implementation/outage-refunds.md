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

Final scoped validation:

```sh
FOUNDRY_INVARIANT_RUNS=32 FOUNDRY_INVARIANT_DEPTH=60 \
FOUNDRY_INVARIANT_FAIL_ON_REVERT=true BASE_RPC_URL=https://mainnet.base.org \
forge test --match-path 'test/{rounds,threshold}/*' -vv
```

Result: **95 passed, zero failed, zero skipped**, including all four real Base fork tests and both handler suites. The strict handlers reported zero unexpected reverts. `forge fmt --check` and `git diff --check` also pass. No deployment was performed.


Integration validation:

```sh
FOUNDRY_INVARIANT_RUNS=128 FOUNDRY_INVARIANT_DEPTH=100 \
FOUNDRY_INVARIANT_FAIL_ON_REVERT=true BASE_RPC_URL=https://mainnet.base.org \
forge test --no-match-path 'test/PredictionMarket.t.sol' -vv
```

Result: **137 passed across 23 suites, zero failed, zero skipped**. Each strict handler executed 12,800 calls with zero unexpected reverts or discards. The unfinished original challenge suite is excluded. Formatting and diff whitespace checks passed.

Slither scanned 25 contracts with 102 detectors and reported 154 results. Triage found no actionable new finding: the high-severity report is OpenZeppelin's intentional XOR in the modular inverse seed; medium reports concern intentional integer rounding, enum/sentinel and endpoint equality, or unchanged reader/library/challenge code. Timeout comparisons are intentional and covered at each boundary. Low-level refund payments check success and use checks/effects/interactions and reentrancy protection. Existing challenge token shadowing and zero-address reports are outside this change. This triage is not a security audit. Runtime bytecode sizes are 11,246 bytes for UpDownRounds and 10,617 bytes for ThresholdPots.

Independent Standards and Spec reviews against integration base `005edeb4e87684e1a0c3875791b9858a6b042a59` both reported no findings. The Standards review checked documented repository conventions and material code smells; the Spec review checked issue #6 and its parent requirements, including payer recovery and custody equalities.

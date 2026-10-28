# Base pool Readings — issue #2

`BasePoolReader` is the shared Uniswap v3 Reading module for the future Round contracts. It has no chain-ID gate: Base mainnet is the target, and the same code runs on Base Sepolia, anvil or any chain with a v3-compatible pool. Deploy one reader per pool, base token and lookback. Either pool token can be the base token; the other is the quote token. Both tokens must expose ERC-20 metadata with 0–18 decimals.

Only Uniswap v3 pools are supported. Uniswap v4 and Aerodrome pools were not compared, so a pool on either needs its own review before it can back a Reading.

## Public seam and units

- `BasePoolReader.capture()` records only a geometric TWAP ending at the current block timestamp. The first successful capture in a block wins; repeated calls return the same price Reading.
- `BasePoolReader.read(endBlock)` returns a previously captured `Reading(blockNumber, timestamp, price)`. Missing, future or uncaptured blocks revert `NoValidReading`; no spot-price fallback exists. Price capture never calls `totalSupply()` and works with metadata-only tokens.
- `MarketCapReader(priceReader, supplyMode, vettedFixedSupply)` fixes the price reader, its base token and the eligibility mode at deployment. There is no alternate caller-selected supply oracle.
- `MarketCapReader.readMarketCap(endBlock)` requires a completed block (`endBlock < block.number`), reads its captured price, and returns that Reading plus historical raw `totalSupply` and `marketCap`. A missing capture or unusable supply source reverts `NoValidMarketCap`.
- Price is whole quote tokens per whole base token, scaled by `PRICE_SCALE` = 1e36: `price = floor(rawRatio × 10^(36 + baseDecimals − quoteDecimals))`, computed in one `mulDiv` so there is a single floor. The 1e36 scale gives tokens priced below 1e-18 quote per base a Reading, and lets Ties compare at full precision: one tick apart at 1e-20 still gives different prices.
- `marketCap = floor(price × endBlockSupply / 10^baseDecimals)`, in whole quote tokens scaled by 1e36. This is pool-relative market cap, not automatically USD unless the quote token represents USD.
- Range limits. A price below 1e-36 floors to zero and reverts `NoValidReading`. A price that exceeds uint256 also reverts `NoValidReading`, never a `mulDiv` panic. That happens only at extreme ticks with mismatched decimals: at `MAX_TICK` with an 18-decimal base and a 0-decimal quote, the raw ratio of about 3.4e38 times 10^54 overflows. Equal decimals at `MAX_TICK` fit. A market cap above uint256 reverts `NoValidMarketCap`, never a panic.
- Uniswap cumulative ticks give a time-weighted geometric price, rather than an arithmetic average of spot prices. Negative mean ticks round toward negative infinity, following Uniswap's oracle library.

The scripted `test/mocks/MockBasePool.sol` implements the same observation surface. Call `write(tick)` after `vm.warp` / `vm.roll`; that tick applies until the next write. It integrates cumulative ticks over elapsed time and returns protocol-style interpolated endpoints. `setMissing(true)` makes the whole pool unavailable. `setMissingAtBlock(blockNumber, true)` fails `observe` only while executing in that block, so refund-path tests can script one missed boundary capture while later blocks still read. Both Round test suites can reuse this pool. Market-cap tests also integrate the installed OpenZeppelin `ERC20Votes` implementation for actual historical supply checkpoints.

## Approved supply eligibility

On 2026-10-27 the user chose eligibility restrictions over execution-time supply: market-cap Readings support vetted immutable fixed-supply tokens or vetted block-number historical supply checkpoints. Other tokens remain price-only. This resolves the earlier review's execution-supply requirement and flash-mint capture defect; the reader no longer captures supply during the boundary transaction.

`SupplyMode` is immutable:

- **Unsupported:** every market-cap request rejects. The underlying price reader remains usable and does not require any supply interface.
- **Fixed:** use the explicitly vetted raw `vettedFixedSupply` constant. Deployment checks it is nonzero and equals current `totalSupply()` as a configuration sanity check. That equality is not proof of eligibility. Before choosing this mode, inspect the token's code and deployment to establish an immutable implementation and supply: exclude upgradeable tokens and every mint, burn, rebase or flash-mint path. An operator falsely labelling a mutable token Fixed can configure incorrect market caps; eligibility is a deployment prerequisite.
- **Checkpoints:** the source is the price reader's base token. Each request requires `CLOCK_MODE()` to equal `mode=blocknumber&from=default` and `clock()` to equal the current block number, then uses `getPastTotalSupply(endBlock)`. There is no current-supply fallback. Timestamp clocks, missing interfaces, failed historical lookups or inconsistent clocks reject. Vet that the implementation truthfully checkpoints the complete ERC-20 supply at block boundaries and cannot be upgraded to change that guarantee; clock/interface checks alone cannot prove those semantics. OpenZeppelin `ERC20Votes` is the tested integration.

Completed-block lookup prevents a transient flash mint from becoming the market-cap supply. The regression test captures price during a million-token mint, burns those tokens, and adds 500 tokens before the endpoint block ends. The historical Reading uses the final 1,500-token supply; another 5,000-token mint in a later block has no effect. Fixed mode similarly uses an immutable supply that equals every endpoint's supply.

## Boundary captures

Readings stay block-captured. On 2026-10-27 the user confirmed that a missed boundary capture refunds; the Round does not reconstruct the boundary price later.

A standard pool exposes timestamps, not authenticated historical block timestamps. The reader never accepts a caller-supplied historical timestamp or reconstructs timestamps from an assumed block interval.

Future Round integrations must capture the scheduled boundary block and retain its block number. Delayed settlement reads that capture and, for market cap, the eligible supply at the same completed block. A missed boundary must refund; taking a later capture and labelling it the missed boundary would be incorrect. This adds a boundary-capture liveness requirement beyond merely calling settle after the Window.

## Confirmed pool and lookback

The fork fixture is Base block **35,000,000**, timestamp **1756789347**, using Uniswap v3 WETH/USDC fee 500 pool **0xd0b53D9277642d899DF5C87A3966A349A798F224**. Token0 is WETH (18 decimals), token1 USDC (6 decimals). Its 30-second Reading is **4387.361616078113586889108985462512617258 USDC/WETH**, stored as `4387361616078113586889108985462512617258` at the 1e36 scale. The fork also successfully reads a 4-second lookback.

The supported lookback is **4–60 seconds** (`MIN_LOOKBACK` and `MAX_LOOKBACK`). Four seconds is the shortest supported multi-block lookback under the specified 2-second Base block interval. The pool mechanically accepts 1- or 2-second observations, but a 2-second interval can be entirely occupied by one block's spike. Use **30 seconds** for the initial Campaigns: a deterministic test applies a roughly tenfold price for one 2-second block and verifies the 30-second Reading moves less than 20%. This attenuation is not an economic manipulation-resistance guarantee; each Campaign's Stake cap still needs separate pool-specific analysis.

The pinned pool holds **13,633,808.2112 USDC** at this endpoint, exceeding the spec's $100,000 reserve floor. Six Swap logs from blocks **34,961,200** and **34,962,300**, both within the preceding 24 hours, establish a daily quote-volume lower bound of **60,683.852190 USDC**, exceeding the $50,000 volume floor. Raw logs, block timestamps, transaction hashes and provenance are retained in [base-pool-volume-evidence.json](base-pool-volume-evidence.json). This is a lower bound, not a claim to have measured the complete day. Reproduce with `cast rpc eth_getBlockReceipts 0x2157730 --rpc-url https://mainnet.base.org` and the same command for `0x2157b7c`; filter the pool's Swap topic and sum absolute signed second ABI words (USDC amount1, six decimals).

## Validation

```sh
cd packages/foundry
forge test --match-path 'test/readings/*'
BASE_RPC_URL=https://mainnet.base.org forge test --match-contract BasePoolReaderForkTest -vv
forge fmt --check contracts/readings test/readings test/mocks/MockBasePool.sol
```

Without `BASE_RPC_URL`, the fork test explicitly skips. The endpoint must support archive reads at the fixed block; RPC failures fail the opt-in test rather than becoming a passing mock test.

42 tests pass under `test/readings/` with `BASE_RPC_URL` set: 28 deterministic, 10 fuzz, 3 invariant and the fork test.

- **Deterministic (28):** 19 in `BasePoolReader.t.sol` and 9 in `MarketCapReader.t.sol`. They cover TWAP pinning and spike attenuation, unavailable and insufficient observations, one block's missing observation, missing/future endpoints, metadata-only price tokens, negative tick rounding, a non-Base chain id, a sub-1e-18 price, full-precision Tie comparison, extreme ticks in both decimal directions, fixed-supply configuration, market-cap overflow, actual OpenZeppelin checkpoint integration, transient flash-mint supply, later-block supply changes, same-block market-cap refusal, unsupported tokens and invalid/failing checkpoint sources. The lookback boundary is pinned separately on each side: 3 seconds rejects, 4 accepts and spans more than one block, 60 accepts, 61 rejects.
- **Price and lookback fuzz (7, `BasePoolReader.fuzz.t.sol`):** the lookback is bounded over its whole accepted domain [4, 60]. A constant tick reads the same price at any lookback, and a two-tick TWAP lies between the two constant-tick prices. The price math is searched over every tick from `MIN_TICK` to `MAX_TICK`, 0–18 decimals on both tokens and both pool directions. A capture must give a nonzero price or revert exactly `NoValidReading`; a panic or any other revert data fails. The checks are properties, not a copy of the formula. Tick 0 equals the decimal scale exactly. Price is monotonic in tick, rising when the base is token0 and falling when it is token1. Reading one pool from both sides gives reciprocals within the exact flooring loss, `1e72 − P0 − P1 − 1 < P0 × P1 ≤ 1e72`. Decimals above 18 reject.
- **Market-cap fuzz (3, `MarketCapReader.fuzz.t.sol`):** price and supply are fuzzed over the full uint256 range, and again with shifted magnitudes so products land on both sides of the overflow limit. Each result is checked against an independent reference that splits both operands by the base unit and checks overflow by division, not with `mul512`. An exact-limit test shows that `type(uint256).max × 1` fits and `× 2` rejects.
- **Handler invariant (3, `BasePoolReader.invariant.t.sol`):** `targetContract` is a handler, with selectors restricted to its actions. The handler advances blocks, moves time within a block, writes ticks (including after a capture), toggles a missing observation for the current block, and captures. The invariants: a captured Reading never changes, either in `read()` or in a repeated `capture()`; every visited block without a capture and the next future block revert `NoValidReading`; and a capture fails only where a gap was scripted. Each invariant ran 128 runs × 100 depth = 12,800 calls with 0 reverts (`fail-on-revert` is on), about 2,500 calls per selector.

Mutation checks confirmed that these tests can fail. Removing the price overflow guard fails the panic fuzz. Changing the token1-base ratio fails the tick-0 fuzz. Adding one unit to `marketCap` fails both market-cap fuzzers. Relaxing `high >= baseUnit` to `>` passes both fuzzers but fails the exact-limit test, which is why that test exists. Disabling the first-capture-wins cache fails two invariants. All mutations were reverted.

Red/green evidence from the first pass includes the first price test failing on missing modules, the metadata-only token failing `NoValidReading` before supply capture was removed, and the OpenZeppelin historical-supply regression failing on the absent `MarketCapReader` module before implementation. The review fixes added: the non-Base chain test failing `InvalidConfiguration` under the old chain gate, a 60-second lookback failing `InvalidConfiguration` under the 30-second ceiling, the sub-1e-18 price and Tie tests failing `NoValidReading` at the 1e18 scale, the extreme-tick test not reverting before the overflow guard, the market-cap overflow test hitting a raw arithmetic panic, and the per-block missing test failing to compile before `setMissingAtBlock` existed.

The full suite has 42 passing tests, 41 failing challenge tests and one explicitly skipped fork test without the RPC environment variable. The challenge contract at the integration base is still the unimplemented exercise; `PredictionMarket.sol`, `PredictionMarketToken.sol` and `PredictionMarket.t.sol` are byte-identical to that base. Existing uncommitted challenge solutions in the original checkout were neither copied nor changed.

## Slither triage

`uvx --from slither-analyzer slither .` was run from `packages/foundry`. The triage covers `contracts/readings` and the library code it calls. Challenge-contract findings (`PredictionMarket` locked ether, `PredictionMarketToken` shadowing and zero-check) are out of scope and left alone. No finding needed a code change.

| Detector | Impact | Location | Handling |
| --- | --- | --- | --- |
| incorrect-exp | High | OpenZeppelin `Math.mulDiv`, `(3 * denominator) ^ 2` | False positive. The XOR is the intended seed for OpenZeppelin's Newton inverse, which is correct to 4 bits. It is dependency code and was not modified. The price and market-cap fuzzers exercise `mulDiv` across the full range. |
| divide-before-multiply | Medium | `TickMath.getSqrtRatioAtTick`, `type(uint256).max / ratio` | False positive. This is verbatim Uniswap v3 code: it takes the reciprocal for positive ticks, after which nothing is multiplied. The monotonic, reciprocal and tick-0 fuzzers cover every tick. The other hits are inside OpenZeppelin `Math`. |
| incorrect-equality | Medium | `BasePoolReader.read`, `reading.timestamp == 0` | False positive. Zero is the uncaptured sentinel. `capture` requires `block.timestamp >= i_lookback >= 4`, so a stored Reading never has timestamp 0. The invariant checks that uncaptured blocks revert and captured ones read back. |
| uninitialized-local | Medium | `BasePoolReader.capture`, `cumulatives` | False positive. The variable is assigned in the `try` success branch, and the `catch` branch reverts `NoValidReading`. |
| unused-return | Medium | `BasePoolReader._mulDiv` and `MarketCapReader.readMarketCap`, low word of `Math.mul512` | Intentional. Only the high word decides overflow: `x × y / d` fits in uint256 if and only if `high < d`. `mulDiv` then computes the result. The panic fuzzer, the independent market-cap reference and the exact-limit test cover this boundary. |
| timestamp | Low | `capture` and `read` comparisons | Accepted. These are sentinel and history-length checks, not deadlines; a few seconds of skew cannot change a captured Reading. |
| assembly, pragma, solc-version, cyclomatic-complexity, dead-code, naming-convention, too-many-digits | Informational | OpenZeppelin, TickMath constants, `i_` immutables | Accepted. The `i_`/`s_` naming is the project convention, and the TickMath constants are Uniswap's. |

## Sources

- [Uniswap oracle semantics](https://docs.uniswap.org/concepts/protocol/oracle)
- [Uniswap TickMath source](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol): vendored `getSqrtRatioAtTick` only, GPL-2.0-or-later retained; Solidity pragma and explicit signed conversion adapted for Solidity 0.8.
- [OpenZeppelin Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol): `getPastTotalSupply` reads completed block-number checkpoints; current blocks are unavailable. Current API documentation was fetched through Context7 and checked against the installed source.
- [Uniswap OracleLibrary](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol): negative rounding and quote-conversion reference.

This ticket adds no deployments, sent transactions, account actions or frontend configuration.

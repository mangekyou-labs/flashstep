# Base pool Readings — issue #2

`BasePoolReader` is the shared Uniswap v3 Reading module for the future Round contracts. It supports Base mainnet (8453) and Base Sepolia (84532). Deploy one reader per pool, base token and lookback. Either pool token can be the base token; the other is the quote token. Both tokens must expose ERC-20 metadata with 0–18 decimals.

## Public seam and units

- `capture()` records a geometric TWAP ending at the current block timestamp and the base token's supply at execution. The first successful capture in a block wins; repeated calls return it unchanged.
- `read(endBlock)` returns only a previously captured Reading. Missing, future or uncaptured blocks revert `NoValidReading`; current supply or a spot price is never substituted.
- `Reading.price` is whole quote tokens per whole base token, scaled by 1e18. `totalSupply` is raw base-token units. `marketCap = floor(price × totalSupply / 10^baseDecimals)`, in whole quote tokens scaled by 1e18. This is pool-relative market cap, not automatically USD unless the quote token represents USD.
- Uniswap cumulative ticks give a time-weighted geometric price, rather than an arithmetic average of spot prices. Negative mean ticks round toward negative infinity, following Uniswap's oracle library.
- A failed observation, insufficient pool history, invalid tick or zero rounded price cannot produce a Reading. There is no privileged reporter.

The scripted `test/mocks/MockBasePool.sol` implements the same observation surface. Call `write(tick)` after `vm.warp` / `vm.roll`; that tick applies until the next write. It integrates cumulative ticks over elapsed time and returns protocol-style interpolated endpoints. `setMissing(true)` simulates an unavailable observation. Both Round test suites can reuse this pool and the mutable-supply token fixture.

## Boundary and supply limitations

A standard pool exposes timestamps, not authenticated historical block timestamps. A standard ERC-20 exposes current `totalSupply()`, not historical supply. The reader therefore never accepts a caller-supplied historical timestamp or reconstructs timestamps from an assumed block interval.

Future Round integrations must capture the scheduled boundary block and retain its block number. Delayed settlement may read that capture. A missed boundary must refund; taking a later capture and labelling it the missed boundary would be incorrect. This adds a boundary-capture liveness requirement beyond merely calling settle after the Window.

**Supply is sampled at capture execution, not proved at finalized end-of-block state.** A mint or burn later in that same block can change final supply. Literal finalized end-block supply for arbitrary mutable ERC-20s requires a historical-checkpoint token or verified historical state proof. This module does not claim that capability. Fixed-supply tokens avoid that distinction; mutable-supply Campaigns must resolve it before market-cap settlement is enabled.

## Review status

Issue #2 remains open. The standards review found no issues; the spec review identified an unresolved P1 requirement: captured supply is not finalized end-block supply. The user decision on supply semantics is pending.

Market-cap settlement must not be enabled for mutable-supply or flash-mintable tokens with the current module. Because capture is permissionless and the first capture wins, a caller can flash-mint, capture the inflated supply, and burn before the transaction ends. The stored market cap then retains that transient supply even though the block ends with a different total supply.

Supporting generic end-block supply requires an authenticated historical checkpoint or verified state proof. Accepting execution-time capture supply instead requires explicit token-eligibility restrictions that exclude transient supply manipulation. The current implementation does not enforce those restrictions, and this review note does not narrow the approved spec or resolve the requirement.

## Confirmed pool and lookback

The fork fixture is Base block **35,000,000**, timestamp **1756789347**, using Uniswap v3 WETH/USDC fee 500 pool **0xd0b53D9277642d899DF5C87A3966A349A798F224**. Token0 is WETH (18 decimals), token1 USDC (6 decimals). Its 30-second Reading is **4387.361616078113586889 USDC/WETH**. The fork also successfully reads a 4-second lookback.

The supported lookback is **4–30 seconds**. Four seconds is the shortest supported multi-block lookback under the specified 2-second Base block interval. The pool mechanically accepts 1- or 2-second observations, but a 2-second interval can be entirely occupied by one block's spike. Use **30 seconds** for the initial Campaigns: a deterministic test applies a roughly tenfold price for one 2-second block and verifies the 30-second Reading moves less than 20%. This attenuation is not an economic manipulation-resistance guarantee; stake limits still need separate pool-specific analysis.

The pinned pool holds **13,633,808.2112 USDC** at this endpoint, exceeding the spec's $100,000 reserve floor. Six Swap logs from blocks **34,961,200** and **34,962,300**, both within the preceding 24 hours, establish a daily quote-volume lower bound of **60,683.852190 USDC**, exceeding the $50,000 volume floor. Raw logs, block timestamps, transaction hashes and provenance are retained in [base-pool-volume-evidence.json](base-pool-volume-evidence.json). This is a lower bound, not a claim to have measured the complete day. Reproduce with `cast rpc eth_getBlockReceipts 0x2157730 --rpc-url https://mainnet.base.org` and the same command for `0x2157b7c`; filter the pool's Swap topic and sum absolute signed second ABI words (USDC amount1, six decimals).

## Validation

```sh
cd packages/foundry
forge test --match-contract BasePoolReaderTest
BASE_RPC_URL=https://mainnet.base.org forge test --match-contract BasePoolReaderForkTest -vv
forge fmt --check contracts/readings test/readings test/mocks/MockBasePool.sol
```

Without `BASE_RPC_URL`, the fork test explicitly skips. The endpoint must support archive reads at the fixed block; RPC failures fail the opt-in test rather than becoming a passing mock test.

11 deterministic tests pass, covering TWAP pinning, the spike, unavailable and insufficient observations, missing/future blocks, immutable supply capture, decimal normalization in both directions, negative tick rounding, the minimum lookback, network/token validation and Base Sepolia. The real fork test passes separately. Red/green evidence includes the first Reading test failing on missing modules before implementation, and Base Sepolia failing `InvalidConfiguration` before adding testnet support.

The full suite has 12 passing tests, 41 failing challenge tests and one explicitly skipped fork test without the RPC environment variable. The challenge contract at the integration base is still the unimplemented exercise; `PredictionMarket.sol`, `PredictionMarketToken.sol` and `PredictionMarket.t.sol` are byte-identical to that base. Existing uncommitted challenge solutions in the original checkout were neither copied nor changed.

## Sources

- [Uniswap oracle semantics](https://docs.uniswap.org/concepts/protocol/oracle)
- [Uniswap TickMath source](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol): vendored `getSqrtRatioAtTick` only, GPL-2.0-or-later retained; Solidity pragma and explicit signed conversion adapted for Solidity 0.8.
- [Uniswap OracleLibrary](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol): negative rounding and quote-conversion reference.

This ticket adds no deployments, sent transactions, account actions or frontend configuration.

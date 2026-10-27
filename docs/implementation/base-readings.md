# Base pool Readings — issue #2

`BasePoolReader` is the shared Uniswap v3 Reading module for the future Round contracts. It supports Base mainnet (8453) and Base Sepolia (84532). Deploy one reader per pool, base token and lookback. Either pool token can be the base token; the other is the quote token. Both tokens must expose ERC-20 metadata with 0–18 decimals.

## Public seam and units

- `BasePoolReader.capture()` records only a geometric TWAP ending at the current block timestamp. The first successful capture in a block wins; repeated calls return the same price Reading.
- `BasePoolReader.read(endBlock)` returns a previously captured `Reading(blockNumber, timestamp, price)`. Missing, future or uncaptured blocks revert `NoValidReading`; no spot-price fallback exists. Price capture never calls `totalSupply()` and works with metadata-only tokens.
- `MarketCapReader(priceReader, supplyMode, vettedFixedSupply)` fixes the price reader, its base token and the eligibility mode at deployment. There is no alternate caller-selected supply oracle.
- `MarketCapReader.readMarketCap(endBlock)` requires a completed block (`endBlock < block.number`), reads its captured price, and returns that Reading plus historical raw `totalSupply` and `marketCap`. A missing capture or unusable supply source reverts `NoValidMarketCap`.
- Price is whole quote tokens per whole base token, scaled by 1e18. `marketCap = floor(price × endBlockSupply / 10^baseDecimals)`, in whole quote tokens scaled by 1e18. This is pool-relative market cap, not automatically USD unless the quote token represents USD.
- Uniswap cumulative ticks give a time-weighted geometric price, rather than an arithmetic average of spot prices. Negative mean ticks round toward negative infinity, following Uniswap's oracle library.

The scripted `test/mocks/MockBasePool.sol` implements the same observation surface. Call `write(tick)` after `vm.warp` / `vm.roll`; that tick applies until the next write. It integrates cumulative ticks over elapsed time and returns protocol-style interpolated endpoints. `setMissing(true)` simulates an unavailable observation. Both Round test suites can reuse this pool. Market-cap tests also integrate the installed OpenZeppelin `ERC20Votes` implementation for actual historical supply checkpoints.

## Approved supply eligibility

On 2026-10-27 the user chose eligibility restrictions over execution-time supply: market-cap Readings support vetted immutable fixed-supply tokens or vetted block-number historical supply checkpoints. Other tokens remain price-only. This resolves the earlier review's execution-supply requirement and flash-mint capture defect; the reader no longer captures supply during the boundary transaction.

`SupplyMode` is immutable:

- **Unsupported:** every market-cap request rejects. The underlying price reader remains usable and does not require any supply interface.
- **Fixed:** use the explicitly vetted raw `vettedFixedSupply` constant. Deployment checks it is nonzero and equals current `totalSupply()` as a configuration sanity check. That equality is not proof of eligibility. Before choosing this mode, inspect the token's code and deployment to establish an immutable implementation and supply: exclude upgradeable tokens and every mint, burn, rebase or flash-mint path. An operator falsely labelling a mutable token Fixed can configure incorrect market caps; eligibility is a deployment prerequisite.
- **Checkpoints:** the source is the price reader's base token. Each request requires `CLOCK_MODE()` to equal `mode=blocknumber&from=default` and `clock()` to equal the current block number, then uses `getPastTotalSupply(endBlock)`. There is no current-supply fallback. Timestamp clocks, missing interfaces, failed historical lookups or inconsistent clocks reject. Vet that the implementation truthfully checkpoints the complete ERC-20 supply at block boundaries and cannot be upgraded to change that guarantee; clock/interface checks alone cannot prove those semantics. OpenZeppelin `ERC20Votes` is the tested integration.

Completed-block lookup prevents a transient flash mint from becoming the market-cap supply. The regression test captures price during a million-token mint, burns those tokens, and adds 500 tokens before the endpoint block ends. The historical Reading uses the final 1,500-token supply; another 5,000-token mint in a later block has no effect. Fixed mode similarly uses an immutable supply that equals every endpoint's supply.

## Boundary captures

A standard pool exposes timestamps, not authenticated historical block timestamps. The reader never accepts a caller-supplied historical timestamp or reconstructs timestamps from an assumed block interval.

Future Round integrations must capture the scheduled boundary block and retain its block number. Delayed settlement reads that capture and, for market cap, the eligible supply at the same completed block. A missed boundary must refund; taking a later capture and labelling it the missed boundary would be incorrect. This adds a boundary-capture liveness requirement beyond merely calling settle after the Window.

## Confirmed pool and lookback

The fork fixture is Base block **35,000,000**, timestamp **1756789347**, using Uniswap v3 WETH/USDC fee 500 pool **0xd0b53D9277642d899DF5C87A3966A349A798F224**. Token0 is WETH (18 decimals), token1 USDC (6 decimals). Its 30-second Reading is **4387.361616078113586889 USDC/WETH**. The fork also successfully reads a 4-second lookback.

The supported lookback is **4–30 seconds**. Four seconds is the shortest supported multi-block lookback under the specified 2-second Base block interval. The pool mechanically accepts 1- or 2-second observations, but a 2-second interval can be entirely occupied by one block's spike. Use **30 seconds** for the initial Campaigns: a deterministic test applies a roughly tenfold price for one 2-second block and verifies the 30-second Reading moves less than 20%. This attenuation is not an economic manipulation-resistance guarantee; stake limits still need separate pool-specific analysis.

The pinned pool holds **13,633,808.2112 USDC** at this endpoint, exceeding the spec's $100,000 reserve floor. Six Swap logs from blocks **34,961,200** and **34,962,300**, both within the preceding 24 hours, establish a daily quote-volume lower bound of **60,683.852190 USDC**, exceeding the $50,000 volume floor. Raw logs, block timestamps, transaction hashes and provenance are retained in [base-pool-volume-evidence.json](base-pool-volume-evidence.json). This is a lower bound, not a claim to have measured the complete day. Reproduce with `cast rpc eth_getBlockReceipts 0x2157730 --rpc-url https://mainnet.base.org` and the same command for `0x2157b7c`; filter the pool's Swap topic and sum absolute signed second ABI words (USDC amount1, six decimals).

## Validation

```sh
cd packages/foundry
forge test --match-path 'test/readings/*'
BASE_RPC_URL=https://mainnet.base.org forge test --match-contract BasePoolReaderForkTest -vv
forge fmt --check contracts/readings test/readings test/mocks/MockBasePool.sol
```

Without `BASE_RPC_URL`, the fork test explicitly skips. The endpoint must support archive reads at the fixed block; RPC failures fail the opt-in test rather than becoming a passing mock test.

20 deterministic tests pass across price and market-cap interfaces. They cover TWAP pinning and spike attenuation, unavailable and insufficient observations, missing/future endpoints, metadata-only price tokens, negative tick rounding, Base network checks, both decimal directions, fixed-supply configuration, actual OpenZeppelin checkpoint integration, transient flash-mint supply, later-block supply changes, same-block market-cap refusal, unsupported tokens and invalid/failing checkpoint sources. The real fork test passes separately; mutable WETH is explicitly price-only and its market-cap request rejects.

Red/green evidence includes the first price test failing on missing modules, Base Sepolia failing `InvalidConfiguration` before support was added, the metadata-only token failing `NoValidReading` before supply capture was removed, and the OpenZeppelin historical-supply regression failing on the absent `MarketCapReader` module before implementation.

The full suite has 21 passing tests, 41 failing challenge tests and one explicitly skipped fork test without the RPC environment variable. The challenge contract at the integration base is still the unimplemented exercise; `PredictionMarket.sol`, `PredictionMarketToken.sol` and `PredictionMarket.t.sol` are byte-identical to that base. Existing uncommitted challenge solutions in the original checkout were neither copied nor changed.

## Sources

- [Uniswap oracle semantics](https://docs.uniswap.org/concepts/protocol/oracle)
- [Uniswap TickMath source](https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol): vendored `getSqrtRatioAtTick` only, GPL-2.0-or-later retained; Solidity pragma and explicit signed conversion adapted for Solidity 0.8.
- [OpenZeppelin Votes](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/utils/Votes.sol): `getPastTotalSupply` reads completed block-number checkpoints; current blocks are unavailable. Current API documentation was fetched through Context7 and checked against the installed source.
- [Uniswap OracleLibrary](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/OracleLibrary.sol): negative rounding and quote-conversion reference.

This ticket adds no deployments, sent transactions, account actions or frontend configuration.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { TickMath } from "../../contracts/readings/TickMath.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

/// @notice Searches the lookback domain and the tick × decimals × direction price domain.
contract BasePoolReaderFuzzTest is Test {
    /// @dev Ticks where an 18/18-decimal Reading is always nonzero and below uint256.
    int24 internal constant SAFE_TICK = 400_000;

    MockReadingToken internal base;
    MockReadingToken internal quote;

    function setUp() public {
        vm.warp(1_000);
        vm.roll(500);
        base = new MockReadingToken(18, 0);
        quote = new MockReadingToken(18, 0);
    }

    // ---------------------------------------------------------------- lookback

    /// A constant tick has the same Reading whatever lookback in [MIN_LOOKBACK, MAX_LOOKBACK] averages it.
    function testFuzzConstantTickReadingIsIndependentOfLookback(uint256 lookbackSeed, int256 tickSeed) public {
        uint32 lookback = uint32(bound(lookbackSeed, 4, 60));
        int24 tick = int24(bound(tickSeed, -SAFE_TICK, SAFE_TICK));
        MockBasePool pool = new MockBasePool(address(base), address(quote));
        pool.write(tick);
        BasePoolReader fuzzed = new BasePoolReader(address(pool), address(base), lookback);
        BasePoolReader reference_ = new BasePoolReader(address(pool), address(base), 30);
        vm.warp(1_060);
        vm.roll(530);
        assertEq(fuzzed.capture().price, reference_.capture().price);
    }

    /// Two ticks inside any accepted lookback give a Reading between the two constant-tick prices.
    function testFuzzTwapLiesBetweenItsTickPricesForEveryLookback(
        uint256 lookbackSeed,
        int256 tickASeed,
        int256 tickBSeed,
        uint256 switchSeed
    ) public {
        uint32 lookback = uint32(bound(lookbackSeed, 4, 60));
        int24 tickA = int24(bound(tickASeed, -SAFE_TICK, SAFE_TICK));
        int24 tickB = int24(bound(tickBSeed, -SAFE_TICK, SAFE_TICK));
        uint256 secondsOfB = bound(switchSeed, 0, lookback);
        uint256 end = 1_100;

        MockBasePool mixed = new MockBasePool(address(base), address(quote));
        MockBasePool onlyA = new MockBasePool(address(base), address(quote));
        MockBasePool onlyB = new MockBasePool(address(base), address(quote));
        mixed.write(tickA);
        onlyA.write(tickA);
        onlyB.write(tickB);
        BasePoolReader reader = new BasePoolReader(address(mixed), address(base), lookback);
        BasePoolReader readerA = new BasePoolReader(address(onlyA), address(base), lookback);
        BasePoolReader readerB = new BasePoolReader(address(onlyB), address(base), lookback);

        vm.warp(end - secondsOfB);
        vm.roll(550 - secondsOfB / 2);
        mixed.write(tickB);
        vm.warp(end);
        vm.roll(550);

        uint256 price = reader.capture().price;
        uint256 priceA = readerA.capture().price;
        uint256 priceB = readerB.capture().price;
        assertGe(price, Math.min(priceA, priceB));
        assertLe(price, Math.max(priceA, priceB));
    }

    // -------------------------------------------------------------- price math

    /// Every tick, decimal pair and direction either yields a nonzero price or reverts NoValidReading.
    function testFuzzPriceIsNonzeroOrNoValidReadingNeverAPanic(
        int256 tickSeed,
        uint256 baseDecimalsSeed,
        uint256 quoteDecimalsSeed,
        bool baseIsToken0
    ) public {
        int24 tick = int24(bound(tickSeed, TickMath.MIN_TICK, TickMath.MAX_TICK));
        BasePoolReader reader = _reader(tick, _decimals(baseDecimalsSeed), _decimals(quoteDecimalsSeed), baseIsToken0);
        vm.warp(1_004);
        vm.roll(502);
        (bool ok, uint256 price) = _tryCapture(reader);
        if (ok) assertGt(price, 0);
    }

    /// Tick 0 is exactly 1 raw quote per raw base, so the price is exactly 10^(36 + base − quote decimals).
    function testFuzzTickZeroPriceIsExactlyTheDecimalScale(
        uint256 baseDecimalsSeed,
        uint256 quoteDecimalsSeed,
        bool baseIsToken0
    ) public {
        uint8 baseDecimals = _decimals(baseDecimalsSeed);
        uint8 quoteDecimals = _decimals(quoteDecimalsSeed);
        BasePoolReader reader = _reader(0, baseDecimals, quoteDecimals, baseIsToken0);
        vm.warp(1_004);
        vm.roll(502);
        uint256 expected = 10 ** 36;
        if (baseDecimals >= quoteDecimals) expected *= 10 ** (baseDecimals - quoteDecimals);
        else expected /= 10 ** (quoteDecimals - baseDecimals);
        assertEq(reader.capture().price, expected);
    }

    /// Higher tick means more token1 per token0: base-as-token0 prices rise, base-as-token1 prices fall.
    function testFuzzPriceIsMonotonicInTickForBothDirections(
        int256 lowSeed,
        int256 highSeed,
        uint256 baseDecimalsSeed,
        uint256 quoteDecimalsSeed,
        bool baseIsToken0
    ) public {
        int24 low = int24(bound(lowSeed, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        int24 high = int24(bound(highSeed, int256(low) + 1, TickMath.MAX_TICK));
        uint8 baseDecimals = _decimals(baseDecimalsSeed);
        uint8 quoteDecimals = _decimals(quoteDecimalsSeed);
        BasePoolReader lowReader = _reader(low, baseDecimals, quoteDecimals, baseIsToken0);
        BasePoolReader highReader = _reader(high, baseDecimals, quoteDecimals, baseIsToken0);
        vm.warp(1_004);
        vm.roll(502);
        (bool lowOk, uint256 lowPrice) = _tryCapture(lowReader);
        (bool highOk, uint256 highPrice) = _tryCapture(highReader);
        if (!lowOk || !highOk) return;
        if (baseIsToken0) assertGe(highPrice, lowPrice);
        else assertLe(highPrice, lowPrice);
    }

    /// Reading the same pool from both sides gives reciprocal prices: P0 × P1 ≈ 1e72 up to flooring.
    /// Each floor loses under one unit, so 1e72 × (1 − 1/P0 − 1/P1) ≤ P0 × P1 ≤ 1e72.
    function testFuzzBothDirectionsAreReciprocalWithinFlooring(
        int256 tickSeed,
        uint256 decimals0Seed,
        uint256 decimals1Seed
    ) public {
        int24 tick = int24(bound(tickSeed, TickMath.MIN_TICK, TickMath.MAX_TICK));
        MockReadingToken token0 = new MockReadingToken(_decimals(decimals0Seed), 0);
        MockReadingToken token1 = new MockReadingToken(_decimals(decimals1Seed), 0);
        MockBasePool pool = new MockBasePool(address(token0), address(token1));
        pool.write(tick);
        BasePoolReader base0 = new BasePoolReader(address(pool), address(token0), 4);
        BasePoolReader base1 = new BasePoolReader(address(pool), address(token1), 4);
        vm.warp(1_004);
        vm.roll(502);
        (bool ok0, uint256 price0) = _tryCapture(base0);
        (bool ok1, uint256 price1) = _tryCapture(base1);
        if (!ok0 || !ok1) return;
        uint256 product = Math.mulDiv(price0, price1, 1e36); // P0 × P1 / 1e36, floored.
        assertLe(product, 1e36);
        assertGe(product + 1e36 / price0 + 1e36 / price1 + 1, 1e36);
    }

    function testDecimalsAboveEighteenAreRejected() public {
        MockReadingToken wide = new MockReadingToken(19, 0);
        MockBasePool pool = new MockBasePool(address(wide), address(quote));
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(wide), 30);
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(quote), 30);
    }

    // ------------------------------------------------------------------ helpers

    function _decimals(uint256 seed) internal pure returns (uint8) {
        return uint8(bound(seed, 0, 18));
    }

    function _reader(int24 tick, uint8 baseDecimals, uint8 quoteDecimals, bool baseIsToken0)
        internal
        returns (BasePoolReader)
    {
        MockReadingToken baseToken = new MockReadingToken(baseDecimals, 0);
        MockReadingToken quoteToken = new MockReadingToken(quoteDecimals, 0);
        MockBasePool pool = baseIsToken0
            ? new MockBasePool(address(baseToken), address(quoteToken))
            : new MockBasePool(address(quoteToken), address(baseToken));
        pool.write(tick);
        return new BasePoolReader(address(pool), address(baseToken), 4);
    }

    /// @dev Any revert other than exactly NoValidReading (a panic, an empty revert) fails the test.
    function _tryCapture(BasePoolReader reader) internal returns (bool ok, uint256 price) {
        try reader.capture() returns (BasePoolReader.Reading memory reading) {
            return (true, reading.price);
        } catch (bytes memory reason) {
            assertEq(reason, abi.encodeWithSelector(BasePoolReader.NoValidReading.selector));
            return (false, 0);
        }
    }
}

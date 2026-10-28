// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

/// @notice Searches the whole accepted lookback domain.
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
}

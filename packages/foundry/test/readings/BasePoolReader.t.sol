// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract BasePoolReaderTest is Test {
    MockReadingToken internal token;
    MockReadingToken internal quote;
    MockBasePool internal pool;
    BasePoolReader internal reader;

    function setUp() public {
        vm.warp(1_000);
        vm.roll(500);
        token = new MockReadingToken(18, 1_000 ether);
        quote = new MockReadingToken(18, 0);
        pool = new MockBasePool(address(token), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(token), 30);
    }

    function testReadingUsesTwapAndPinsItsEndpoint() public {
        vm.warp(1_030);
        vm.roll(515);
        pool.write(0);
        BasePoolReader.Reading memory reading = reader.capture();
        assertEq(reading.price, 1e36);
        assertEq(reading.blockNumber, 515);
        assertEq(reading.timestamp, 1_030);
        vm.warp(1_100);
        vm.roll(550);
        assertEq(reader.read(515).price, 1e36);
    }

    function testOneBlockTenfoldSpikeIsStronglyDamped() public {
        vm.warp(1_028);
        vm.roll(514);
        pool.write(23027); // 1.0001^23027 is about 10 times the baseline.
        vm.warp(1_030);
        vm.roll(515);
        pool.write(0);
        BasePoolReader.Reading memory reading = reader.capture();
        assertGt(reading.price, 1e36);
        assertLt(reading.price, 1.2e36); // <20% movement versus a roughly900% spike.
    }

    function testMissingObservationCannotProduceAReading() public {
        vm.warp(1_030);
        vm.roll(515);
        pool.setMissing(true);
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        reader.capture();
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        reader.read(515);
    }

    function testInsufficientHistoryCannotProduceAReading() public {
        vm.warp(1_029);
        vm.roll(514);
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        reader.capture();
    }

    function testMissingAndFutureBlocksCannotUseALatestReading() public {
        vm.warp(1_030);
        vm.roll(515);
        reader.capture();
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        reader.read(514);
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        reader.read(516);
    }

    function testCapturedPriceStaysPinnedWhenSupplyChanges() public {
        vm.warp(1_030);
        vm.roll(515);
        reader.capture();
        token.setTotalSupply(3_000 ether);
        vm.warp(1_032);
        vm.roll(516);
        assertEq(reader.read(515).price, 1e36);
    }

    function testNegativeMeanTickRoundsDown() public {
        pool.write(-1);
        vm.warp(1_001);
        vm.roll(501);
        pool.write(0);
        vm.warp(1_030);
        vm.roll(515);
        assertApproxEqRel(reader.capture().price, 999900009999000099990000999900009999, 1e6);
    }

    function testPriceBelowOneQuintillionthStillProducesAReading() public {
        pool.write(-460517); // 1.0001^-460517 is about 1.0023e-20 quote per base.
        vm.warp(1_030);
        vm.roll(515);
        assertApproxEqRel(reader.capture().price, 10023069483065370, 0.0001 ether);
    }

    function testTiesCompareAtFullPrecision() public {
        pool.write(-460517);
        vm.warp(1_030);
        vm.roll(515);
        uint256 lower = reader.capture().price;
        pool.write(-460516);
        vm.warp(1_060);
        vm.roll(530);
        assertGt(reader.capture().price, lower); // One tick apart at 1e-20 is not a Tie.
    }

    function testExtremeTicksInBothDecimalDirectionsNeverPanic() public {
        MockReadingToken zero = new MockReadingToken(0, 0);
        // Base token0 at MAX_TICK: about 3.4e38 raw quote per raw base.
        MockBasePool high = new MockBasePool(address(token), address(zero));
        high.write(887272);
        // Base token1 at MIN_TICK: the same raw ratio from the other side.
        MockBasePool low = new MockBasePool(address(zero), address(token));
        low.write(-887272);
        BasePoolReader highBase18Quote0 = new BasePoolReader(address(high), address(token), 30);
        BasePoolReader lowBase18Quote0 = new BasePoolReader(address(low), address(token), 30);
        BasePoolReader highBase0Quote18 = new BasePoolReader(address(high), address(zero), 30);
        BasePoolReader lowBase0Quote18 = new BasePoolReader(address(low), address(zero), 30);
        MockBasePool same = new MockBasePool(address(token), address(quote));
        same.write(887272);
        BasePoolReader highBase18Quote18 = new BasePoolReader(address(same), address(token), 30);
        vm.warp(1_030);
        vm.roll(515);
        // 3.4e38 * 1e18 / 1 * 1e36 exceeds uint256: no Reading rather than a panic.
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        highBase18Quote0.capture();
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        lowBase18Quote0.capture();
        // The opposite side is about 2.9e-39 * 1 / 1e18, below 1e-36: no Reading.
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        highBase0Quote18.capture();
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        lowBase0Quote18.capture();
        // Equal decimals at MAX_TICK fit: about 3.4e38 quote per base, scaled by 1e36.
        assertApproxEqRel(highBase18Quote18.capture().price, 340256786836e63, 0.0001 ether);
    }

    function testSixAndEighteenDecimalTokensAndReverseQuote() public {
        MockReadingToken six = new MockReadingToken(6, 1_000e6);
        MockBasePool mixed = new MockBasePool(address(six), address(token));
        mixed.write(276324); // Raw quote ratio approximately 1e12, human price approximately1.
        BasePoolReader forward = new BasePoolReader(address(mixed), address(six), 30);
        BasePoolReader reverse = new BasePoolReader(address(mixed), address(token), 30);
        vm.warp(1_030);
        vm.roll(515);
        assertApproxEqRel(forward.capture().price, 1e36, 0.0001 ether);
        assertApproxEqRel(reverse.capture().price, 1e36, 0.0001 ether);
    }

    function testMinimumLookbackIsMoreThanOneTwoSecondBlock() public {
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(token), 2);
        BasePoolReader shortest = new BasePoolReader(address(pool), address(token), 4);
        vm.warp(1_004);
        vm.roll(502);
        assertEq(shortest.capture().price, 1e36);
    }

    function testLookbackCeilingIsSixtySeconds() public {
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(token), 61);
        BasePoolReader longest = new BasePoolReader(address(pool), address(token), 60);
        vm.warp(1_060);
        vm.roll(530);
        assertEq(longest.capture().price, 1e36);
    }

    function testRejectsTokenOutsideThePool() public {
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(0x1234), 30);
    }

    function testReaderWorksOnANonBaseChain() public {
        vm.chainId(31337);
        BasePoolReader localReader = new BasePoolReader(address(pool), address(token), 30);
        vm.warp(1_030);
        vm.roll(515);
        assertEq(localReader.capture().price, 1e36);
    }

    function testPriceOnlyTokenDoesNotNeedTotalSupply() public {
        MetadataOnlyToken priceToken = new MetadataOnlyToken();
        MockBasePool pricePool = new MockBasePool(address(priceToken), address(quote));
        pricePool.write(0);
        BasePoolReader priceReader = new BasePoolReader(address(pricePool), address(priceToken), 30);
        vm.warp(1_030);
        vm.roll(515);
        assertEq(priceReader.capture().price, 1e36);
    }
}

contract MetadataOnlyToken {
    function decimals() external pure returns (uint8) {
        return 18;
    }
}

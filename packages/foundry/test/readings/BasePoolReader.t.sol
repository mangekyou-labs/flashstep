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
        vm.chainId(8453);
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
        assertEq(reading.price, 1 ether);
        assertEq(reading.marketCap, 1_000 ether);
        assertEq(reading.blockNumber, 515);
        assertEq(reading.timestamp, 1_030);
        vm.warp(1_100);
        vm.roll(550);
        assertEq(reader.read(515).price, 1 ether);
    }

    function testOneBlockTenfoldSpikeIsStronglyDamped() public {
        vm.warp(1_028);
        vm.roll(514);
        pool.write(23027); // 1.0001^23027 is about 10 times the baseline.
        vm.warp(1_030);
        vm.roll(515);
        pool.write(0);
        BasePoolReader.Reading memory reading = reader.capture();
        assertGt(reading.price, 1 ether);
        assertLt(reading.price, 1.2 ether); // <20% movement versus a roughly900% spike.
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

    function testSupplyIsCapturedWithPriceAndNeverReplacedByLaterSupply() public {
        vm.warp(1_030);
        vm.roll(515);
        token.setTotalSupply(2_000 ether);
        BasePoolReader.Reading memory first = reader.capture();
        assertEq(first.marketCap, 2_000 ether);
        token.setTotalSupply(3_000 ether);
        assertEq(reader.capture().totalSupply, 2_000 ether); // Same block is immutable.
        vm.warp(1_032);
        vm.roll(516);
        assertEq(reader.capture().marketCap, 3_000 ether);
        assertEq(reader.read(515).marketCap, 2_000 ether);
    }

    function testNegativeMeanTickRoundsDown() public {
        pool.write(-1);
        vm.warp(1_001);
        vm.roll(501);
        pool.write(0);
        vm.warp(1_030);
        vm.roll(515);
        assertApproxEqAbs(reader.capture().price, 999900009999000099, 1);
    }

    function testSixAndEighteenDecimalTokensAndReverseQuote() public {
        MockReadingToken six = new MockReadingToken(6, 1_000e6);
        MockBasePool mixed = new MockBasePool(address(six), address(token));
        mixed.write(276324); // Raw quote ratio approximately 1e12, human price approximately1.
        BasePoolReader forward = new BasePoolReader(address(mixed), address(six), 30);
        BasePoolReader reverse = new BasePoolReader(address(mixed), address(token), 30);
        vm.warp(1_030);
        vm.roll(515);
        assertApproxEqRel(forward.capture().price, 1 ether, 0.0001 ether);
        assertApproxEqRel(reverse.capture().price, 1 ether, 0.0001 ether);
        assertApproxEqRel(forward.read(515).marketCap, 1_000 ether, 0.0001 ether);
    }

    function testMinimumLookbackIsMoreThanOneTwoSecondBlock() public {
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(token), 2);
        BasePoolReader shortest = new BasePoolReader(address(pool), address(token), 4);
        vm.warp(1_004);
        vm.roll(502);
        assertEq(shortest.capture().price, 1 ether);
    }

    function testRejectsWrongChainAndToken() public {
        vm.chainId(1);
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(token), 30);
        vm.chainId(8453);
        vm.expectRevert(BasePoolReader.InvalidConfiguration.selector);
        new BasePoolReader(address(pool), address(0x1234), 30);
    }

    function testBaseSepoliaUsesTheSameReadingModuleForPilotRehearsal() public {
        vm.chainId(84532);
        BasePoolReader testnetReader = new BasePoolReader(address(pool), address(token), 30);
        vm.warp(1_030);
        vm.roll(515);
        assertEq(testnetReader.capture().price, 1 ether);
    }
}

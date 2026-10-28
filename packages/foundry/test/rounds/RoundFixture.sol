// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

abstract contract RoundFixture is Test {
    UpDownRounds market;
    BasePoolReader reader;
    MockBasePool pool;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quoteToken = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quoteToken));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        market = new UpDownRounds(address(this), reader);
        vm.deal(address(this), 100 ether);
        market.fund{ value: 10 ether }();
        market.seedRound(1 ether, 1 ether, 10, 4);
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function buyAs(address player, UpDownRounds.Side side, uint256 shares) internal returns (uint256 cost) {
        cost = market.quote(1, side, shares);
        vm.prank(player);
        market.buy{ value: cost }(1, side, shares, cost);
    }

    function finish(int24 tick) internal {
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        pool.write(tick);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        vm.warp(130);
        vm.roll(25);
        market.settle(1);
    }
}

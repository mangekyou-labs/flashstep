// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract UpDownRoundsFuzzTest is RoundFixture {
    function fresh(uint256 seed, uint256 cap) internal returns (UpDownRounds m) {
        m = new UpDownRounds(address(this), reader);
        vm.deal(address(this), seed);
        m.fund{ value: seed }();
        m.seedRound(seed, cap, 10, 4);
    }

    function testFuzzSeedAndCapConserveETH(uint256 rawSeed, uint256 rawCap, uint256 rawShares, bool up) public {
        uint256 seed = bound(rawSeed, 1e16, 1e30);
        uint256 cap = bound(rawCap, 1, 1e30);
        UpDownRounds m = fresh(seed, cap);
        uint256 shares = bound(rawShares, 1, seed * 90);
        UpDownRounds.Side side = up ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
        uint256 cost = m.quote(1, side, shares);
        vm.deal(alice, cost);
        if (cost > cap) {
            vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
            vm.prank(alice);
            m.buy{ value: cost }(1, side, shares, cost);
            assertEq(address(m).balance, seed);
        } else {
            vm.prank(alice);
            m.buy{ value: cost }(1, side, shares, cost);
            assertEq(address(m).balance + alice.balance, seed + cost);
            vm.warp(110);
            vm.roll(15);
            m.captureBoundary(1);
            pool.write(up ? int24(100) : int24(-100));
            vm.warp(114);
            vm.roll(17);
            m.captureBoundary(1);
            m.settle(1);
            uint256 owed = m.claimable(1, alice);
            assertLe(owed, seed);
            vm.prank(alice);
            m.claim(1);
            assertEq(address(m).balance + alice.balance, seed + cost);
        }
    }

    function testCumulativeCapAtExactLimitAndFirstWeiBeyond() public {
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 20e18);
        UpDownRounds m = fresh(1 ether, cost);
        vm.prank(alice);
        m.buy{ value: cost }(1, UpDownRounds.Side.Up, 20e18, cost);
        uint256 next = m.quote(1, UpDownRounds.Side.Down, 1);
        assertEq(next, 1);
        vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
        vm.prank(alice);
        m.buy{ value: 1 }(1, UpDownRounds.Side.Down, 1, 1);
        assertEq(address(m).balance, 1 ether + cost);
    }

    function testAcceptedCapBoundariesAndFirstBeyond() public {
        UpDownRounds m = fresh(1e16, 1);
        vm.prank(alice);
        m.buy{ value: 1 }(1, UpDownRounds.Side.Up, 1, 1);
        vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
        vm.prank(alice);
        m.buy{ value: 1 }(1, UpDownRounds.Side.Down, 1, 1);
        fresh(1e16, 1e30 - 1);
        fresh(1e16, 1e30);
        m = new UpDownRounds(address(this), reader);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        m.seedRound(1e16, 0, 10, 4);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        m.seedRound(1e16, 1e30 + 1, 10, 4);
    }

    function testSeedBoundariesAndReserveLimit() public {
        uint256[4] memory accepted = [uint256(1e16), 1e16 + 1, 1e30 - 1, 1e30];
        for (uint256 i; i < accepted.length; ++i) {
            UpDownRounds m = fresh(accepted[i], 1e30);
            uint256 reserve = accepted[i] * 90;
            uint256 cost = m.quote(1, UpDownRounds.Side.Up, reserve);
            vm.deal(alice, cost);
            vm.prank(alice);
            m.buy{ value: cost }(1, UpDownRounds.Side.Up, reserve, cost);
            vm.expectRevert(UpDownRounds.InsufficientReserve.selector);
            m.quote(1, UpDownRounds.Side.Up, 1);
        }
        UpDownRounds invalid = new UpDownRounds(address(this), reader);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        invalid.seedRound(1e16 - 1, 1, 10, 4);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        invalid.seedRound(1e30 + 1, 1, 10, 4);
    }
}

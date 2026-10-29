// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract UpDownRoundsFuzzTest is RoundFixture {
    function fresh(uint256 seed, uint256 cap) internal returns (UpDownRounds m) {
        m = _newUpDown(address(this), reader);
        _deal(address(this), seed);
        m.fund{ value: _value(seed) }(seed);
        m.seedRound(seed, cap, 10, 4);
    }

    function testFuzzSeedAndCapConserveETH(uint256 rawSeed, uint256 rawCap, uint256 rawShares, bool up) public {
        uint256 seed = bound(rawSeed, 1e16, 1e30);
        uint256 cap = bound(rawCap, 1, 1e30);
        UpDownRounds m = fresh(seed, cap);
        uint256 shares = bound(rawShares, 1, seed * 90);
        UpDownRounds.Side side = up ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
        uint256 cost = m.quote(1, side, shares);
        _deal(alice, cost);
        if (cost > cap) {
            vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
            vm.prank(alice);
            m.buy{ value: _value(cost) }(1, side, shares, cost);
            assertEq(_balance(address(m)), seed);
        } else {
            vm.prank(alice);
            m.buy{ value: _value(cost) }(1, side, shares, cost);
            assertEq(_balance(address(m)) + _balance(alice), seed + cost);
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
            assertEq(_balance(address(m)) + _balance(alice), seed + cost);
        }
    }

    function testCumulativeCapAtExactLimitAndFirstWeiBeyond() public {
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 20e18);
        UpDownRounds m = fresh(1 ether, cost);
        vm.prank(alice);
        m.buy{ value: _value(cost) }(1, UpDownRounds.Side.Up, 20e18, cost);
        uint256 next = m.quote(1, UpDownRounds.Side.Down, 1);
        assertEq(next, 1);
        vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
        vm.prank(alice);
        m.buy{ value: _value(1) }(1, UpDownRounds.Side.Down, 1, 1);
        assertEq(_balance(address(m)), 1 ether + cost);
    }

    function testAcceptedCapBoundariesAndFirstBeyond() public {
        UpDownRounds m = fresh(1e16, 1);
        vm.prank(alice);
        m.buy{ value: _value(1) }(1, UpDownRounds.Side.Up, 1, 1);
        vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
        vm.prank(alice);
        m.buy{ value: _value(1) }(1, UpDownRounds.Side.Down, 1, 1);
        fresh(1e16, 1e30 - 1);
        fresh(1e16, 1e30);
        m = _newUpDown(address(this), reader);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        m.seedRound(1e16, 0, 10, 4);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        m.seedRound(1e16, 1e30 + 1, 10, 4);
    }

    function testRejectsEveryUnsupportedOddDurationBeforeTrading() public {
        // On two-second Base blocks, former (5,4) and (10,1) settings
        // placed at least one exact endpoint between blocks.
        for (uint32 duration = 1; duration <= 31; duration += 2) {
            UpDownRounds m = _newUpDown(address(this), reader);
            m.fund{ value: _value(1 ether) }(1 ether);
            vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
            m.seedRound(1 ether, 1 ether, duration, 4);
            vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
            m.seedRound(1 ether, 1 ether, 10, duration);
            m.seedRound(1 ether, 1 ether, 6, 2);
        }
    }

    function testEvenDurationBoundariesCaptureOnTwoSecondBlocks() public {
        uint32[2] memory trading = [uint32(6), 30];
        uint32[2] memory windows = [uint32(2), 30];
        for (uint256 i; i < trading.length; ++i) {
            for (uint256 j; j < windows.length; ++j) {
                UpDownRounds m = _newUpDown(address(this), reader);
                m.fund{ value: _value(1 ether) }(1 ether);
                m.seedRound(1 ether, 1 ether, trading[i], windows[j]);
                UpDownRounds.Round memory r = m.round(1);
                uint256 simulatedTime = r.cutoff - trading[i];
                uint256 simulatedBlock = block.number;
                while (simulatedTime < r.windowEnd) {
                    simulatedTime += 2;
                    vm.warp(simulatedTime);
                    vm.roll(++simulatedBlock);
                    if (simulatedTime == r.cutoff || simulatedTime == r.windowEnd) m.captureBoundary(1);
                }
                m.settle(1);
                assertEq(uint256(m.phase(1)), uint256(UpDownRounds.Phase.Settled));
            }
        }
    }

    function testSeedBoundariesAndReserveLimit() public {
        uint256[4] memory accepted = [uint256(1e16), 1e16 + 1, 1e30 - 1, 1e30];
        for (uint256 i; i < accepted.length; ++i) {
            UpDownRounds m = fresh(accepted[i], 1e30);
            uint256 reserve = accepted[i] * 90;
            uint256 cost = m.quote(1, UpDownRounds.Side.Up, reserve);
            _deal(alice, cost);
            vm.prank(alice);
            m.buy{ value: _value(cost) }(1, UpDownRounds.Side.Up, reserve, cost);
            vm.expectRevert(UpDownRounds.InsufficientReserve.selector);
            m.quote(1, UpDownRounds.Side.Up, 1);
        }
        UpDownRounds invalid = _newUpDown(address(this), reader);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        invalid.seedRound(1e16 - 1, 1, 10, 4);
        vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
        invalid.seedRound(1e30 + 1, 1, 10, 4);
    }
}

contract UpDownRoundsFuzzTestERC20 is UpDownRoundsFuzzTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

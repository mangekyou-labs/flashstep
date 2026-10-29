// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract UpDownCampaignFuzzTest is RoundFixture {
    function testFuzzCampaignTimingsAndCap(uint256 rawTrading, uint256 rawWindow, uint256 rawCap) public {
        uint32 trading = uint32(bound(rawTrading, 5, 30));
        uint32 window = uint32(bound(rawWindow, 1, 30));
        uint256 cap = bound(rawCap, 1, 1e30);
        if (trading % 2 != 0 || window % 2 != 0) {
            vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
            market.setCampaignSettings(1 ether, cap, trading, window, 300, reader);
            return;
        }
        market.setCampaignSettings(1 ether, cap, trading, window, 300, reader);
        vm.warp(110);
        vm.roll(15);
        assertEq(market.currentRound(), 2);
        uint256 cost = market.quote(2, UpDownRounds.Side.Up, 1);
        vm.prank(alice);
        market.buy{ value: _value(cost) }(2, UpDownRounds.Side.Up, 1, cost);
        // The one-wei minimum cap accepts one dust purchase, and cumulative buys cannot exceed it.
        if (cap == 1) {
            vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
            vm.prank(alice);
            market.buy{ value: _value(cost) }(2, UpDownRounds.Side.Up, 1, cost);
        }
        vm.warp(110 + trading - 1);
        assertEq(uint256(market.phase(2)), uint256(UpDownRounds.Phase.Trading));
        vm.warp(110 + trading);
        vm.roll(15 + trading / 2);
        assertEq(market.currentRound(), 3);
        market.captureBoundary(2);
        vm.warp(110 + trading + window);
        vm.roll(15 + trading / 2 + window / 2);
        market.captureBoundary(2);
        market.settle(2);
        vm.prank(alice);
        assertEq(market.claim(2), cost);
    }

    function testExplicitSpecTimingBoundariesAndFirstInvalidValues() public {
        uint32[4] memory trading = [uint32(4), 5, 30, 31];
        uint32[4] memory window = [uint32(0), 1, 30, 31];
        for (uint256 i; i < trading.length; ++i) {
            if (trading[i] != 30) vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
            market.setCampaignSettings(1 ether, 1 ether, trading[i], 4, 300, reader);
            if (window[i] != 30) vm.expectRevert(UpDownRounds.InvalidConfiguration.selector);
            market.setCampaignSettings(1 ether, 1 ether, 10, window[i], 300, reader);
        }
    }

    function testFuzzTiePaysCumulativeBuysMinusProceedsFlooredOnce(bytes32 entropy, uint256 rawActions) public {
        market = _newUpDown(address(this), reader);
        market.fund{ value: _value(10 ether) }(10 ether);
        market.seedRound(1 ether, 1e30, 10, 4);
        uint256 actions = bound(rawActions, 2, 32);
        uint256[2] memory paid;
        uint256[2] memory received;
        for (uint256 i; i < actions; ++i) {
            uint256 random = uint256(keccak256(abi.encode(entropy, i)));
            uint256 index = random % 2;
            address player = index == 0 ? alice : bob;
            UpDownRounds.Side side = (random >> 1) % 2 == 0 ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
            UpDownRounds.Position memory position = market.positionOf(1, player);
            if ((random >> 2) % 2 == 0) {
                UpDownRounds.Round memory r = market.round(1);
                uint256 reserve = r.sharesPerSide - (side == UpDownRounds.Side.Up ? r.upSold : r.downSold);
                if (reserve == 0) continue;
                uint256 shares = bound(random >> 3, 1, reserve < 20e18 ? reserve : 20e18);
                uint256 cost = market.quote(1, side, shares);
                uint256 beforeBalance = _balance(player);
                vm.prank(player);
                market.buy{ value: _value(cost) }(1, side, shares, cost);
                paid[index] += beforeBalance - _balance(player);
            } else {
                uint256 owned = side == UpDownRounds.Side.Up ? position.up : position.down;
                if (owned == 0) continue;
                uint256 shares = bound(random >> 3, 1, owned);
                uint256 proceeds = market.quoteSell(1, side, shares);
                uint256 beforeBalance = _balance(player);
                vm.prank(player);
                try market.sell(1, side, shares, proceeds) {
                    received[index] += _balance(player) - beforeBalance;
                } catch (bytes memory reason) {
                    assertEq(bytes4(reason), UpDownRounds.InsufficientReserve.selector);
                    assertEq(_balance(player), beforeBalance);
                }
            }
        }
        finish(0);
        for (uint256 i; i < 2; ++i) {
            address player = i == 0 ? alice : bob;
            uint256 expected = paid[i] > received[i] ? paid[i] - received[i] : 0;
            uint256 beforeBalance = _balance(player);
            vm.prank(player);
            market.claim(1);
            assertEq(_balance(player) - beforeBalance, expected);
            assertEq(market.claimable(1, player), 0);
        }
    }
}

contract UpDownCampaignFuzzTestERC20 is UpDownCampaignFuzzTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

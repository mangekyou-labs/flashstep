// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract UpDownCampaignTest is RoundFixture {
    function testSellPaysQuoteAndTieRefundsOnlyNetPaid() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 20e18);
        uint256 proceeds = market.quoteSell(1, UpDownRounds.Side.Up, 10e18);
        uint256 beforeBalance = _balance(alice);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 10e18, proceeds);
        assertEq(_balance(alice) - beforeBalance, proceeds);
        finish(0);
        assertEq(market.claimable(1, alice), paid - proceeds);
        beforeBalance = _balance(alice);
        vm.prank(alice);
        market.claim(1);
        assertEq(_balance(alice) - beforeBalance, paid - proceeds);
    }

    function testOwnerWithdrawsOnlyUncommittedFundingAndSettledSurplus() public {
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        uint256 playerPaid = 100 ether - _balance(alice);
        uint256 beforeBalance = _balance(address(this));
        market.withdrawLiquidity(9 ether);
        assertEq(_balance(address(this)) - beforeBalance, 9 ether);
        vm.expectRevert(UpDownRounds.InsufficientFunding.selector);
        market.withdrawLiquidity(1);
        finish(100);
        uint256 owed = market.claimable(1, alice);
        assertEq(owed, 0.01 ether);
        market.withdrawLiquidity(1 ether + playerPaid - owed);
        assertEq(_balance(address(market)), owed);
        vm.prank(alice);
        market.claim(1);
        assertEq(_balance(address(market)), 0);
    }

    function testNextRoundTradesWhilePreviousWindowKeepsItsBookAndResult() public {
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        vm.warp(110);
        vm.roll(15);
        assertEq(market.currentRound(), 2);
        market.captureBoundary(1);
        pool.write(100);
        uint256 cost = market.quote(2, UpDownRounds.Side.Down, 2e18);
        vm.prank(bob);
        market.buy{ value: _value(cost) }(2, UpDownRounds.Side.Down, 2e18, cost);
        assertEq(market.positionOf(1, bob).down, 0);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        market.settle(1);
        assertEq(market.claimable(1, alice), 0.01 ether);
        assertEq(market.claimable(2, bob), 0);
        vm.warp(120);
        vm.roll(20);
        market.captureBoundary(2);
        pool.write(-100);
        vm.warp(124);
        vm.roll(22);
        market.captureBoundary(2);
        market.settle(2);
        assertEq(market.claimable(2, bob), 0.02 ether);
        assertEq(market.claimable(1, alice), 0.01 ether);
    }

    function testSettingsApplyFromNextRoundWithoutMovingCurrentCutoff() public {
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        vm.warp(104);
        vm.roll(12);
        market.setCampaignSettings(2 ether, 2 ether, 6, 8, 200, reader);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Trading));
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        assertEq(market.currentRound(), 2);
        // Round 2 starts on the original cutoff and has the newly chosen six-second phase.
        vm.warp(116);
        assertEq(market.currentRound(), 3);
        assertEq(uint256(market.phase(2)), uint256(UpDownRounds.Phase.Window));
        vm.warp(200);
        assertEq(market.currentRound(), 0);
    }

    function testStopKeepsCurrentUntradedRoundAvailableButCreatesNoLaterRound() public {
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        market.stopCampaign();
        uint256 cost = market.quote(2, UpDownRounds.Side.Down, 1e18);
        vm.prank(bob);
        market.buy{ value: _value(cost) }(2, UpDownRounds.Side.Down, 1e18, cost);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        market.settle(1);
        vm.warp(120);
        vm.roll(20);
        assertEq(market.currentRound(), 0);
        vm.expectRevert(UpDownRounds.UnknownRound.selector);
        market.phase(3);
        market.captureBoundary(2);
        pool.write(-100);
        vm.warp(124);
        vm.roll(22);
        market.captureBoundary(2);
        market.settle(2);
        vm.prank(bob);
        assertEq(market.claim(2), 0.01 ether);
        vm.expectRevert(UpDownRounds.CampaignStopped.selector);
        market.setCampaignSettings(1 ether, 1 ether, 10, 4, 1000, reader);
    }

    function testProfitableSellKeepsCreditAcrossLaterBuysAndTiePaysNothing() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 20e18);
        buyAs(bob, UpDownRounds.Side.Up, 60e18);
        uint256 proceeds = market.quoteSell(1, UpDownRounds.Side.Up, 20e18);
        assertGt(proceeds, paid);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 20e18, proceeds);
        uint256 later = buyAs(alice, UpDownRounds.Side.Down, 1e18);
        assertGt(proceeds, paid + later);
        finish(0);
        assertEq(market.claimable(1, alice), 0);
        uint256 beforeBalance = _balance(alice);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
        assertEq(_balance(alice), beforeBalance);
    }

    function testSellDeadlineBalanceAndMinimumProceeds() public {
        buyAs(alice, UpDownRounds.Side.Up, 20e18);
        uint256 proceeds = market.quoteSell(1, UpDownRounds.Side.Up, 10e18);
        vm.expectRevert(UpDownRounds.SlippageExceeded.selector);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 10e18, proceeds + 1);
        vm.expectRevert(UpDownRounds.InsufficientShares.selector);
        vm.prank(bob);
        market.sell(1, UpDownRounds.Side.Up, 1e18, 1);
        vm.warp(110);
        vm.expectRevert(UpDownRounds.OutsideTrading.selector);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 10e18, proceeds);
        vm.warp(114);
        vm.expectRevert(UpDownRounds.OutsideTrading.selector);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 10e18, proceeds);
    }

    function testOwnerActionsRejectPlayers() public {
        bytes memory denied = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice);
        vm.startPrank(alice);
        vm.expectRevert(denied);
        market.withdrawLiquidity(1);
        vm.expectRevert(denied);
        market.stopCampaign();
        vm.expectRevert(denied);
        market.setCampaignSettings(1 ether, 1 ether, 10, 4, 200, reader);
        vm.stopPrank();
    }

    function testSchedulesSkipIdleRoundsWithoutAllocatingTheirSeed() public {
        vm.warp(1000100);
        assertEq(market.currentRound(), 100001);
        uint256 cost = market.quote(100001, UpDownRounds.Side.Up, 1e18);
        vm.prank(alice);
        market.buy{ value: _value(cost) }(100001, UpDownRounds.Side.Up, 1e18, cost);
        assertEq(market.fundingBalance(), 8 ether);
        assertEq(market.positionOf(100001, alice).up, 1e18);
    }

    function testSeedCannotRestartStoppedCampaign() public {
        market.stopCampaign();
        vm.expectRevert(UpDownRounds.RoundAlreadySeeded.selector);
        market.seedRound(1 ether, 1 ether, 10, 4);
    }

    function testCampaignEndFinishesAlreadyScheduledTradingRound() public {
        market.setCampaignSettings(1 ether, 1 ether, 10, 4, 125, reader);
        vm.warp(126);
        assertEq(market.currentRound(), 3);
        uint256 cost = market.quote(3, UpDownRounds.Side.Up, 1e18);
        vm.prank(alice);
        market.buy{ value: _value(cost) }(3, UpDownRounds.Side.Up, 1e18, cost);
        vm.warp(130);
        assertEq(market.currentRound(), 0);
        vm.expectRevert(UpDownRounds.UnknownRound.selector);
        market.round(4);
    }

    function testSellNeverRestoresCumulativeBuyCap() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 90e18);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 90e18, 1);
        assertEq(market.positionOf(1, alice).bought, paid);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 90e18);
        assertGt(paid + cost, 1 ether);
        vm.expectRevert(UpDownRounds.StakeCapExceeded.selector);
        vm.prank(alice);
        market.buy{ value: _value(cost) }(1, UpDownRounds.Side.Up, 90e18, cost);
    }

    function testReaderAndRepeatedSettingsChangesSnapshotAtNextRound() public {
        BasePoolReader nextReader = new BasePoolReader(address(pool), address(reader.i_baseToken()), 6);
        market.setCampaignSettings(2 ether, 3 ether, 6, 8, 200, nextReader);
        // Replacing the pending change must preserve Round 1 and create only one next epoch.
        market.setCampaignSettings(3 ether, 4 ether, 8, 10, 200, nextReader);
        assertEq(address(market.round(1).reader), address(reader));
        assertEq(market.round(1).cutoff, 110);
        vm.warp(110);
        UpDownRounds.Round memory next = market.round(2);
        assertEq(address(next.reader), address(nextReader));
        assertEq(next.seededLiquidity, 3 ether);
        assertEq(next.stakeCap, 4 ether);
        assertEq(next.cutoff, 118);
        assertEq(next.windowEnd, 128);
        // A later epoch must not rewrite the earlier, still lazy snapshot.
        market.setCampaignSettings(1 ether, 2 ether, 10, 4, 200, reader);
        vm.warp(118);
        assertEq(address(market.round(3).reader), address(reader));
        assertEq(address(market.round(2).reader), address(nextReader));
        assertEq(market.round(2).cutoff, 118);
    }

    receive() external payable { }
}

contract UpDownCampaignTestERC20 is UpDownCampaignTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

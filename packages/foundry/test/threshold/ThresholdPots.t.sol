// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ThresholdFixture, ThresholdPots, MarketCapReader } from "./ThresholdFixture.sol";

contract ThresholdPotsTest is ThresholdFixture {
    function testOpeningStakesAreReservedOnBothSides() public {
        market.seedRound(settings());
        assertEq(market.positionOf(1, address(this)).yes, 1 ether);
        assertEq(market.positionOf(1, address(this)).no, 1 ether);
        assertEq(market.fundingBalance(), 8 ether);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2 ether);
        assertEq(market.round(1).pot, 4 ether);
        assertEq(market.reservedBalance(), 4 ether);
        assertEq(_balance(address(market)), 12 ether);
    }

    function testOpeningStakeAndPlayersShareThePotWithNoFee() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.threshold = 1e36 - 1;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2 ether);
        stakeAs(bob, 1, ThresholdPots.Side.No, 2 ether);
        finish(1);
        // 6 ETH pot, 3 ETH Yes. Alice's 2 ETH gets 4; payer's 1 gets 2.
        assertEq(market.claimable(1, alice), 4 ether);
        assertEq(market.claimable(1, address(this)), 2 ether);
        assertEq(market.claimable(1, bob), 0);
        vm.prank(alice);
        assertEq(market.claim(1), 4 ether);
        assertEq(_balance(alice), 102 ether);
        assertEq(market.claim(1), 2 ether);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
        assertEq(market.reservedBalance(), 0);
    }

    function testOnlyUncommittedFundingCanWithdraw() public {
        market.seedRound(settings());
        vm.expectRevert(ThresholdPots.InsufficientFunding.selector);
        market.withdrawFunding(8 ether + 1);
        market.withdrawFunding(8 ether);
        assertEq(_balance(address(market)), 2 ether);
        assertEq(market.reservedBalance(), 2 ether);
    }

    function testRoundingDustBelongsToOriginalPayerAfterAllWinnersClaim() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 1;
        s.threshold -= 1;
        market.seedRound(s);
        market.withdrawFunding(10 ether - 2);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2);
        stakeAs(bob, 1, ThresholdPots.Side.No, 2);
        // Pot 6, winning total 3: these stakes divide exactly. Add No to make pot 7.
        stakeAs(bob, 1, ThresholdPots.Side.No, 1);
        finish(1);
        market.transferOwnership(carol);
        assertEq(market.claim(1), 2);
        assertEq(market.dustCredit(address(this)), 0);
        vm.prank(alice);
        assertEq(market.claim(1), 4);
        assertEq(market.round(1).collateral, 0);
        assertEq(market.dustCredit(address(this)), 1);
        assertEq(market.dustCredit(carol), 0);
        assertEq(market.withdrawDust(), 1);
        assertEq(_balance(address(market)), 0);
    }

    function testSettingsApplyToNextRoundAndStopPreservesCurrent() public {
        market.seedRound(settings());
        ThresholdPots.CampaignSettings memory next = settings();
        next.openingStake = 2 ether;
        next.threshold = 7;
        next.tradingSeconds = 6;
        market.setCampaignSettings(next);
        assertEq(market.round(1).threshold, 1e36);
        vm.warp(110);
        assertEq(market.currentRound(), 2);
        assertEq(uint256(market.phase(1)), uint256(ThresholdPots.Phase.Window));
        stakeAs(alice, 2, ThresholdPots.Side.Yes, 1 ether);
        assertEq(market.round(2).threshold, 7);
        assertEq(market.round(2).cutoff, 116);
        assertEq(market.positionOf(2, address(this)).yes, 2 ether);
        market.stopCampaign();
        stakeAs(bob, 2, ThresholdPots.Side.No, 1 ether);
        vm.warp(116);
        assertEq(market.currentRound(), 0);
        assertEq(market.round(2).windowEnd, 120);
        vm.expectRevert(ThresholdPots.UnknownRound.selector);
        market.round(3);
    }

    function testCapAccumulatesAcrossBothSidesAndOpeningDoesNotConsumeCap() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 6 ether);
        stakeAs(alice, 1, ThresholdPots.Side.No, 4 ether);
        vm.expectRevert(ThresholdPots.StakeCapExceeded.selector);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 1);
        assertEq(market.positionOf(1, alice).paid, 10 ether);
        market.stake{ value: _value(10 ether) }(1, ThresholdPots.Side.Yes, 10 ether);
        assertEq(market.positionOf(1, address(this)).yes, 11 ether);
        vm.warp(110);
        vm.expectRevert(ThresholdPots.OutsideTrading.selector);
        stakeAs(bob, 1, ThresholdPots.Side.No, 1);
    }

    function testTieRefundsEveryStakeIncludingPayerBothSides() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2 ether);
        stakeAs(alice, 1, ThresholdPots.Side.No, 3 ether);
        finish(1);
        assertEq(uint256(market.round(1).result), uint256(ThresholdPots.Result.Tie));
        assertEq(market.claimable(1, alice), 5 ether);
        assertEq(market.claim(1), 2 ether);
        vm.prank(alice);
        assertEq(market.claim(1), 5 ether);
        assertEq(market.reservedBalance(), 0);
        assertEq(market.totalDustCredit(), 0);
    }

    function testUnmatchedRefundDoesNotRequireReadingAndZeroOpeningIsMaterialized() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 0;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2 ether);
        vm.warp(114);
        market.settle(1);
        assertTrue(market.round(1).materialized);
        assertEq(market.round(1).endBlock, 0);
        assertEq(uint256(market.round(1).result), uint256(ThresholdPots.Result.Unmatched));
        vm.prank(alice);
        assertEq(market.claim(1), 2 ether);
        assertEq(market.reservedBalance(), 0);
    }

    function testMissedEndpointCannotUseLaterReadingOrSettleMatchedPot() public {
        market.seedRound(settings());
        vm.warp(115);
        vm.expectRevert(ThresholdPots.OutsideBoundary.selector);
        market.captureBoundary(1);
        vm.expectRevert(ThresholdPots.NoValidReading.selector);
        market.settle(1);
        assertEq(market.reservedBalance(), 2 ether);
    }

    function testIdleSlotsDoNotConsumeFundingAndFinalStartedRoundFinishes() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.endTime = 135;
        market.seedRound(s);
        vm.warp(130);
        assertEq(market.currentRound(), 4);
        assertEq(market.fundingBalance(), 8 ether);
        stakeAs(alice, 4, ThresholdPots.Side.Yes, 1 ether);
        assertEq(market.fundingBalance(), 6 ether);
        vm.warp(136);
        assertEq(market.currentRound(), 4);
        stakeAs(bob, 4, ThresholdPots.Side.No, 1 ether);
        vm.warp(140);
        assertEq(market.currentRound(), 0);
        finish(4);
        assertEq(uint256(market.round(4).result), uint256(ThresholdPots.Result.Tie));
        assertFalse(market.round(2).materialized);
    }

    function testCadenceBoundariesAndStoppedCampaignRejectChanges() public {
        uint32[5] memory invalidTrading = [uint32(4), 5, 7, 31, 32];
        uint32[5] memory invalidWindow = [uint32(0), 1, 3, 31, 32];
        for (uint256 i; i < invalidTrading.length; ++i) {
            ThresholdPots.CampaignSettings memory s = settings();
            s.tradingSeconds = invalidTrading[i];
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(s);
            s = settings();
            s.windowSeconds = invalidWindow[i];
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(s);
        }
        ThresholdPots.CampaignSettings memory valid = settings();
        valid.tradingSeconds = 6;
        valid.windowSeconds = 2;
        market.seedRound(valid);
        valid.tradingSeconds = 30;
        valid.windowSeconds = 30;
        market.setCampaignSettings(valid);
        market.stopCampaign();
        vm.expectRevert(ThresholdPots.CampaignStopped.selector);
        market.setCampaignSettings(valid);
        vm.expectRevert(ThresholdPots.CampaignStopped.selector);
        market.stopCampaign();
    }

    function testRenounceRequiresOriginalPayerToWithdrawUncommittedFunding() public {
        market.seedRound(settings());
        vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
        market.renounceOwnership();
        assertEq(market.owner(), address(this));
        assertEq(market.fundingBalance(), 8 ether);
        market.withdrawFunding(8 ether);
        market.renounceOwnership();
        assertEq(market.owner(), address(0));
        finish(1);
        assertEq(market.claim(1), 2 ether);
        assertEq(_balance(address(market)), 0);
    }

    function testRenouncePreservesOriginalPayerOpeningAndDustClaims() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 1;
        s.threshold -= 1;
        market.seedRound(s);
        market.withdrawFunding(10 ether - 2);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 2);
        stakeAs(bob, 1, ThresholdPots.Side.No, 3);
        market.renounceOwnership();
        finish(1);
        assertEq(market.claim(1), 2);
        vm.prank(alice);
        assertEq(market.claim(1), 4);
        assertEq(market.dustCredit(address(this)), 1);
        assertEq(market.dustCredit(address(0)), 0);
        assertEq(market.withdrawDust(), 1);
        assertEq(_balance(address(market)), 0);
    }

    function testRenouncedLazyRoundsRequireNoOpeningPrefunding() public {
        market.seedRound(settings());
        market.withdrawFunding(8 ether);
        market.renounceOwnership();
        vm.warp(110);
        vm.expectRevert(ThresholdPots.InsufficientFunding.selector);
        stakeAs(alice, 2, ThresholdPots.Side.Yes, 1);
        assertEq(market.reservedBalance(), 2 ether);
        assertFalse(market.round(2).materialized);

        ThresholdPots zeroOpening = _newThreshold(address(this), reader);
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 0;
        zeroOpening.seedRound(s);
        zeroOpening.renounceOwnership();
        vm.warp(120);
        vm.prank(alice);
        zeroOpening.stake{ value: _value(1) }(2, ThresholdPots.Side.Yes, 1);
        vm.warp(134);
        zeroOpening.settle(2);
        vm.prank(alice);
        assertEq(zeroOpening.claim(2), 1);
        assertEq(_balance(address(zeroOpening)), 0);
    }

    function testZeroOpeningAfterRenounceCreditsDustToLastPayer() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 0;
        s.threshold -= 1;
        market.seedRound(s);
        market.withdrawFunding(10 ether);
        market.renounceOwnership();
        vm.warp(110);
        stakeAs(alice, 2, ThresholdPots.Side.Yes, 1);
        stakeAs(bob, 2, ThresholdPots.Side.Yes, 1);
        stakeAs(carol, 2, ThresholdPots.Side.No, 1);
        finish(2);
        vm.prank(alice);
        assertEq(market.claim(2), 1);
        vm.prank(bob);
        assertEq(market.claim(2), 1);
        assertEq(market.round(2).payer, address(this));
        assertEq(market.dustCredit(address(this)), 1);
        assertEq(market.dustCredit(address(0)), 0);
        assertEq(market.withdrawDust(), 1);
        assertEq(_balance(address(market)), 0);
    }
}

contract ThresholdPotsTestERC20 is ThresholdPotsTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

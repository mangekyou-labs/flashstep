// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ThresholdFixture } from "./ThresholdFixture.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";

contract ThresholdRefundsTest is ThresholdFixture {
    function _captureEnd() private {
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        vm.roll(18);
    }

    function testMissingEndObservationRefundsOpeningAndPlayerStakes() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 3 ether);
        pool.setMissingAtBlock(17, true);
        vm.warp(114);
        vm.roll(17);
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        market.captureBoundary(1);
        vm.warp(174);
        vm.roll(47);
        market.settle(1);
        uint256 beforeBalance = alice.balance;
        vm.prank(alice);
        assertEq(market.claim(1), 3 ether);
        assertEq(alice.balance - beforeBalance, 3 ether);
        assertEq(market.claim(1), 2 ether);
    }

    function testMissingReadingDeadlineOneSecondBeforeExactlyAndAfter() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.No, 3 ether);
        vm.warp(173);
        assertEq(uint256(market.phase(1)), uint256(ThresholdPots.Phase.AwaitingSettlement));
        assertEq(market.claimable(1, alice), 0);
        vm.expectRevert(ThresholdPots.NoValidReading.selector);
        market.settle(1);
        vm.warp(174);
        assertEq(uint256(market.phase(1)), uint256(ThresholdPots.Phase.Refunded));
        assertEq(market.claimable(1, alice), 3 ether);
        vm.warp(175);
        vm.prank(alice);
        assertEq(market.claim(1), 3 ether);
        assertEq(market.claim(1), 2 ether);
    }

    function testUnsettledExpiryOneSecondBeforeExactlyAndAfterWithValidReading() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 3 ether);
        _captureEnd();
        vm.warp(114 + 24 hours - 1);
        assertEq(uint256(market.phase(1)), uint256(ThresholdPots.Phase.AwaitingSettlement));
        assertEq(market.claimable(1, alice), 0);
        vm.prank(alice);
        vm.expectRevert(ThresholdPots.NotSettled.selector);
        market.claim(1);
        vm.warp(114 + 24 hours);
        assertEq(uint256(market.phase(1)), uint256(ThresholdPots.Phase.Refunded));
        assertEq(market.claimable(1, alice), 3 ether);
        vm.warp(114 + 24 hours + 1);
        vm.prank(alice);
        assertEq(market.claim(1), 3 ether);
        assertEq(market.claim(1), 2 ether);
        assertEq(uint256(market.round(1).result), uint256(ThresholdPots.Result.Refunded));
    }

    function testValidReadingCanSettleAtGraceDeadline() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.threshold = 1e36 - 1;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 3 ether);
        _captureEnd();
        vm.warp(174);
        market.settle(1);
        assertEq(market.claimable(1, alice), 3.75 ether);
        vm.warp(114 + 3650 days);
        assertEq(market.claimable(1, alice), 3.75 ether);
    }

    function testRefundOpeningRemainsOriginalPayerAfterTransferAndNeverExpires() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 3 ether);
        market.transferOwnership(bob);
        vm.warp(114 + 3650 days);
        uint256 beforeBalance = address(this).balance;
        assertEq(market.claim(1), 2 ether);
        assertEq(address(this).balance - beforeBalance, 2 ether);
        assertEq(market.claim(1), 0);
        vm.prank(alice);
        assertEq(market.claim(1), 3 ether);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
        vm.prank(bob);
        assertEq(market.claim(1), 0);
        assertEq(address(market).balance, 8 ether);
    }

    function testUnavailableHistoricalSupplyRefundsEvenWithCapturedPrice() public {
        // This metadata token deliberately has no checkpoint supply API.
        MarketCapReader caps = new MarketCapReader(reader, MarketCapReader.SupplyMode.Checkpoints, 0);
        ThresholdPots.CampaignSettings memory s = settings();
        s.metric = ThresholdPots.Metric.MarketCap;
        s.marketCapReader = caps;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 3 ether);
        _captureEnd();
        vm.warp(173);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        market.settle(1);
        vm.warp(174);
        vm.prank(alice);
        assertEq(market.claim(1), 3 ether);
        assertEq(market.claim(1), 2 ether);
    }

    function testExpiredIdleSlotsCannotConsumeOpeningFunding() public {
        market.seedRound(settings());
        vm.warp(1000);
        uint256 held = address(market).balance;
        for (uint256 id = 2; id <= 20; ++id) {
            assertEq(market.claimable(id, address(this)), 0);
            assertEq(market.claim(id), 0);
            vm.expectRevert(ThresholdPots.UnknownRound.selector);
            market.settle(id);
        }
        assertEq(market.fundingBalance(), 8 ether);
        assertEq(address(market).balance, held);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {QuirkyStakeToken} from "../stake/QuirkyStakeToken.sol";
import {ThresholdFixture, ThresholdPots, MarketCapReader} from "./ThresholdFixture.sol";

contract ThresholdQuotesTest is ThresholdFixture {
    function testPreviewIncludesExistingStakeAndMatchesClaimable() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.threshold -= 1;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 1 ether);
        stakeAs(alice, 1, ThresholdPots.Side.No, 1 ether);
        stakeAs(bob, 1, ThresholdPots.Side.No, 1 ether);
        // Existing pot 5, Yes 2; an extra Yes makes pot 6, Yes 3.
        assertEq(market.quoteStake(1, alice, ThresholdPots.Side.Yes, 1 ether), 4 ether);
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 1 ether);
        finish(1);
        assertEq(market.claimable(1, alice), 4 ether);
    }

    function testOthersJoiningYourSideShrinkHeldPayout() public {
        market.seedRound(settings());
        stakeAs(alice, 1, ThresholdPots.Side.Yes, 1 ether);
        assertEq(market.quoteStake(1, alice, ThresholdPots.Side.Yes, 0), 1.5 ether);
        stakeAs(bob, 1, ThresholdPots.Side.Yes, 1 ether);
        assertEq(market.quoteStake(1, alice, ThresholdPots.Side.Yes, 0), 1_333_333_333_333_333_333);
    }

    function testRawSixDecimalStakeAmountsPreservePayoutRounding() public {
        ThresholdPots.CampaignSettings memory s = settings();
        s.openingStake = 1_000_000;
        s.threshold += 1;
        market.seedRound(s);
        stakeAs(alice, 1, ThresholdPots.Side.No, 2_000_000);
        stakeAs(bob, 1, ThresholdPots.Side.Yes, 2_000_000);
        assertEq(market.quoteStake(1, alice, ThresholdPots.Side.No, 0), 4_000_000);
        finish(1);
        assertEq(market.claimable(1, alice), 4_000_000);
    }

    function testCurrentPriceAndMarketCapComeFromContractViews() public {
        market.seedRound(settings());
        vm.warp(110);
        vm.roll(15);
        assertEq(market.currentValue(1), 1e36);
        ThresholdPots.CampaignSettings memory s = settings();
        s.metric = ThresholdPots.Metric.MarketCap;
        s.marketCapReader = capReader;
        s.threshold = 100e36;
        market.setCampaignSettings(s);
        vm.warp(120);
        vm.roll(20);
        assertEq(market.currentValue(3), 100e36);
    }
}

contract ThresholdQuotesSixDecimalTest is ThresholdQuotesTest {
    function setUp() public override {
        _setStakeToken(address(new QuirkyStakeToken(6)));
        super.setUp();
    }
}

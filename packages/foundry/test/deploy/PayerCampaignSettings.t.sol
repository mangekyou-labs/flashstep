// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PayerDeployFixture, SignedAsPayer } from "./PayerDeployFixture.sol";
import { DeployPayerCampaign } from "../../script/DeployPayerCampaign.s.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";

/// @notice Seam: the two entry points of the script (`run`, `fundAndSeed`) and the contracts' public views.
/// Every Campaign setting must be readable from the contracts after the script has run.
contract PayerCampaignSettingsTest is PayerDeployFixture {
    UpDownRounds internal upDown;
    ThresholdPots internal threshold;
    BasePoolReader internal priceReader;

    function _deployAndSeed() internal {
        _prepare();
        script.run();
        script.fundAndSeed();
        string memory json = vm.readFile(outPath);
        upDown = UpDownRounds(vm.parseJsonAddress(json, ".upDown"));
        threshold = ThresholdPots(vm.parseJsonAddress(json, ".threshold"));
        priceReader = BasePoolReader(vm.parseJsonAddress(json, ".priceReader"));
    }

    function test_everyUpDownSettingIsReadableFromTheContract() public {
        _deployAndSeed();
        assertEq(upDown.i_stakeToken(), address(quote), "stake token");
        assertEq(address(upDown.i_reader()), address(priceReader), "reader");
        assertEq(upDown.PAYOUT(), 1e18, "payout");
        assertEq(upDown.currentRound(), 1, "round 1 is running");

        UpDownRounds.Round memory r = upDown.round(1);
        assertEq(address(r.reader), address(priceReader), "round reader");
        assertEq(r.payer, payer, "round payer");
        assertEq(r.seededLiquidity, upDownSeed, "seed");
        assertEq(r.stakeCap, upDownCap, "stake cap");
        assertEq(r.cutoff, block.timestamp + upDownTrading, "trading phase");
        assertEq(r.windowEnd, block.timestamp + upDownTrading + upDownWindow, "window");

        assertEq(upDown.fundingBalance(), upDownFunding - upDownSeed, "funding left after the seed");
        assertEq(quote.balanceOf(address(upDown)), upDownFunding, "tokens held");
    }

    function test_everyThresholdSettingIsReadableFromTheContract() public {
        _deployAndSeed();
        assertEq(threshold.i_stakeToken(), address(quote), "stake token");
        assertEq(address(threshold.i_reader()), address(priceReader), "reader");
        assertEq(threshold.currentRound(), 1, "round 1 is running");

        ThresholdPots.Round memory r = threshold.round(1);
        assertEq(address(r.reader), address(priceReader), "round reader");
        assertEq(uint8(r.metric), uint8(ThresholdPots.Metric.Price), "metric");
        assertEq(r.threshold, thresholdValue, "threshold");
        assertEq(r.stakeCap, thresholdCap, "stake cap");
        assertEq(r.openingStake, openingStake, "opening stake");
        assertEq(r.payer, payer, "round payer");
        assertEq(r.cutoff, block.timestamp + thresholdTrading, "trading phase");
        assertEq(r.windowEnd, block.timestamp + thresholdTrading + thresholdWindow, "window");
        assertEq(r.yesTotal, openingStake, "opening stake on yes");
        assertEq(r.noTotal, openingStake, "opening stake on no");

        assertEq(threshold.fundingBalance(), thresholdFunding - 2 * openingStake, "funding left after the Pot");
        assertEq(quote.balanceOf(address(threshold)), thresholdFunding, "tokens held");
    }

    function test_payerPaysEverythingAndLeavesNoStandingAllowance() public {
        uint256 before = quote.balanceOf(payer);
        _deployAndSeed();
        assertEq(quote.balanceOf(payer), before - upDownFunding - thresholdFunding, "payer paid both fundings");
        assertEq(quote.allowance(payer, address(upDown)), 0, "no allowance left to UpDownRounds");
        assertEq(quote.allowance(payer, address(threshold)), 0, "no allowance left to ThresholdPots");
    }

    function test_aCampaignDurationSchedulesTheEndTimeOnBothContracts() public {
        upDownDuration = 3_600;
        thresholdDuration = 3_600;
        uint256 t0 = block.timestamp;
        _deployAndSeed();

        vm.warp(t0 + 3_600 + upDownTrading + thresholdTrading + 1);
        assertEq(upDown.currentRound(), 0, "UpDownRounds stops starting Rounds at the end time");
        assertEq(threshold.currentRound(), 0, "ThresholdPots stops starting Rounds at the end time");
    }

    function test_marketCapMetricDeploysAVettedMarketCapReader() public {
        thresholdMetric = "MarketCap";
        thresholdSupplyMode = "Fixed";
        thresholdFixedSupply = 100e18; // the mock base token's total supply
        _deployAndSeed();
        ThresholdPots.Round memory r = threshold.round(1);
        assertEq(uint8(r.metric), uint8(ThresholdPots.Metric.MarketCap), "metric");
        assertTrue(address(r.marketCapReader) != address(0), "market cap reader set");
        assertEq(address(r.marketCapReader.i_priceReader()), address(priceReader), "same price reader");
        assertEq(uint8(r.marketCapReader.i_supplyMode()), uint8(MarketCapReader.SupplyMode.Fixed), "supply mode");
    }

    function test_fundingMoreThanThePayerHoldsRevertsBeforeAnyTransfer() public {
        upDownFunding = 900e18;
        thresholdFunding = 900e18;
        _prepare();
        script.run();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.PayerBalanceTooLow.selector, 1_800e18, 1_000e18));
        script.fundAndSeed();
    }

    function test_fundAndSeedRefusesASignerThatIsNotTheOwner() public {
        _prepare();
        script.run();
        SignedAsPayer wrong = new SignedAsPayer(developer, configPath, outPath);
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.SignerIsNotPayer.selector, developer, payer));
        wrong.fundAndSeed();
    }
}

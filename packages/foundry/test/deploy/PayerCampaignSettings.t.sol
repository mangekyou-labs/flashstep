// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { PayerDeployFixture, SignedAsPayer } from "./PayerDeployFixture.sol";
import { DeployPayerCampaign } from "../../script/DeployPayerCampaign.s.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";

/// @notice Seam: the two entry points of the script (`run`, `fundAndSeed`) and the contracts' public views.
/// Each Campaign setting is checked the way the runbook says it can be read back. The contracts have no getter for
/// `endTime`, `tradingSeconds` or `windowSeconds`, so the Trading phase and the Window are read as the absolute
/// `cutoff` and `windowEnd` of Round 1 and their lengths are derived from the seed time. `endTime` is read from the
/// `SettingsScheduled` event where one is emitted (UpDownRounds with a duration) and otherwise only by its behaviour.
contract PayerCampaignSettingsTest is PayerDeployFixture {
    UpDownRounds internal upDown;
    ThresholdPots internal threshold;
    BasePoolReader internal priceReader;
    uint256 internal seededAt;

    function _deployAndSeed() internal {
        _prepare();
        script.run();
        seededAt = block.timestamp; // the fixture does not advance time, so this is the seed time of both Campaigns
        script.fundAndSeed();
        string memory json = vm.readFile(outPath);
        upDown = UpDownRounds(vm.parseJsonAddress(json, ".upDown"));
        threshold = ThresholdPots(vm.parseJsonAddress(json, ".threshold"));
        priceReader = BasePoolReader(vm.parseJsonAddress(json, ".priceReader"));
    }

    function test_theUpDownSettingsReadBackFromTheContract() public {
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
        // Read as absolute timestamps; the lengths below are derived from them and the seed time.
        assertEq(r.cutoff, seededAt + upDownTrading, "cutoff: end of the Trading phase");
        assertEq(r.windowEnd, seededAt + upDownTrading + upDownWindow, "windowEnd: end of the Window");
        assertEq(r.cutoff - seededAt, upDownTrading, "derived: Trading phase length");
        assertEq(r.windowEnd - r.cutoff, upDownWindow, "derived: Window length");

        assertEq(upDown.fundingBalance(), upDownFunding - upDownSeed, "funding left after the seed");
        assertEq(quote.balanceOf(address(upDown)), upDownFunding, "tokens held");
    }

    function test_theThresholdSettingsReadBackFromTheContract() public {
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
        assertEq(r.cutoff, seededAt + thresholdTrading, "cutoff: end of the Trading phase");
        assertEq(r.windowEnd, seededAt + thresholdTrading + thresholdWindow, "windowEnd: end of the Window");
        assertEq(r.cutoff - seededAt, thresholdTrading, "derived: Trading phase length");
        assertEq(r.windowEnd - r.cutoff, thresholdWindow, "derived: Window length");
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
        upDownDuration = 3_600; // a multiple of the Trading phase, so the last Round starts exactly one phase early
        thresholdDuration = 3_600;
        vm.recordLogs();
        _deployAndSeed();
        uint256 endTime = seededAt + 3_600;

        // endTime has no getter. UpDownRounds emits it in SettingsScheduled, which the script triggers for a duration.
        UpDownRounds.CampaignSettings memory scheduled = _scheduledUpDownSettings(vm.getRecordedLogs());
        assertEq(scheduled.endTime, endTime, "UpDownRounds end time, from the SettingsScheduled event");
        assertEq(scheduled.tradingSeconds, upDownTrading, "scheduled Trading phase length");
        assertEq(scheduled.windowSeconds, upDownWindow, "scheduled Window length");

        // ThresholdPots takes endTime in seedRound, which emits no event with it: its end time is read by behaviour.
        // New Rounds start while now < endTime, and the last one runs in full; none starts at endTime.
        vm.warp(endTime - 1);
        assertGt(upDown.currentRound(), 0, "UpDownRounds still runs just before the end time");
        assertGt(threshold.currentRound(), 0, "ThresholdPots still runs just before the end time");
        vm.warp(endTime);
        assertEq(upDown.currentRound(), 0, "UpDownRounds starts no Round at the end time");
        assertEq(threshold.currentRound(), 0, "ThresholdPots starts no Round at the end time");
    }

    function _scheduledUpDownSettings(Vm.Log[] memory logs)
        internal
        view
        returns (UpDownRounds.CampaignSettings memory)
    {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(upDown) && logs[i].topics[0] == UpDownRounds.SettingsScheduled.selector) {
                (, UpDownRounds.CampaignSettings memory settings) =
                    abi.decode(logs[i].data, (uint256, UpDownRounds.CampaignSettings));
                return settings;
            }
        }
        revert("no SettingsScheduled event from UpDownRounds");
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

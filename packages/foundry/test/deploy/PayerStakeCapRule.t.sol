// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PayerDeployFixture } from "./PayerDeployFixture.sol";
import { DeployPayerCampaign } from "../../script/DeployPayerCampaign.s.sol";
import { StakeCapRule } from "../../script/lib/StakeCapRule.sol";

/// @notice Seam: `preflight()` and `run()` refuse a Stake cap above the rule of thumb, unless the payer
/// explicitly allows it. The rule's own arithmetic is pinned in StakeCapRule.t.sol.
contract PayerStakeCapRuleTest is PayerDeployFixture {
    function _max(uint256 windowSeconds) internal pure returns (uint256) {
        return StakeCapRule.maxStakeCap(POOL_DEPTH, windowSeconds, 30, 500);
    }

    function setUp() public override {
        super.setUp();
        allowAboveRule = false;
    }

    function test_capsUnderTheRulePass() public {
        upDownCap = _max(upDownWindow);
        thresholdCap = _max(thresholdWindow);
        _prepare();
        script.preflight();
    }

    function test_anUpDownCapOneUnitOverTheRuleIsRefused() public {
        uint256 max = _max(upDownWindow);
        upDownCap = max + 1;
        thresholdCap = max;
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.StakeCapAboveRule.selector, DeployPayerCampaign.Campaign.UpDown, max + 1, max
            )
        );
        script.preflight();
    }

    function test_aThresholdCapOverTheRuleIsRefused() public {
        uint256 max = _max(thresholdWindow);
        upDownCap = max;
        thresholdCap = max * 2;
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.StakeCapAboveRule.selector, DeployPayerCampaign.Campaign.Threshold, max * 2, max
            )
        );
        script.preflight();
    }

    function test_aShorterWindowLowersTheCapTheRuleAllows() public {
        // The cap that is fine for a 30 second Window is too high for a 2 second Window.
        uint256 capForLongWindow = _max(30);
        upDownWindow = 2;
        upDownCap = capForLongWindow;
        thresholdCap = _max(thresholdWindow);
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.StakeCapAboveRule.selector,
                DeployPayerCampaign.Campaign.UpDown,
                capForLongWindow,
                _max(2)
            )
        );
        script.preflight();
    }

    function test_runRefusesToDeployAnOverCap() public {
        upDownCap = _max(upDownWindow) + 1;
        thresholdCap = 1;
        _prepare();
        vm.expectPartialRevert(DeployPayerCampaign.StakeCapAboveRule.selector);
        script.run();
        assertFalse(vm.exists(outPath), "nothing was deployed or written");
    }

    function test_thePayerCanAcceptACapAboveTheRuleOnPurpose() public {
        allowAboveRule = true;
        upDownCap = _max(upDownWindow) * 10;
        thresholdCap = _max(thresholdWindow) * 10;
        _prepare();
        script.preflight();
    }

    function test_aStakeTokenThatIsNotThePoolsQuoteTokenCannotBeChecked() public {
        configuredStakeToken = address(base); // the pool's base token, not its quote token
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.StakeTokenIsNotThePoolQuote.selector, address(base)));
        script.preflight();
    }

    function test_allowingACapAboveTheRuleDoesNotSkipTheStakeTokenIdentityCheck() public {
        allowAboveRule = true;
        configuredStakeToken = address(base); // a contract, but not the pool's quote token
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.StakeTokenIsNotThePoolQuote.selector, address(base)));
        script.preflight();
    }

    function test_allowingACapAboveTheRuleDoesNotSkipTheStakeTokenCodeCheck() public {
        allowAboveRule = true;
        configuredStakeToken = makeAddr("not a contract");
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.NotAContract.selector, DeployPayerCampaign.Vetted.StakeToken, configuredStakeToken
            )
        );
        script.preflight();
    }

    function test_ethIsTheOnlyStakeTokenBesidesTheQuoteAndNeedsTheCapAboveRuleFlag() public {
        configuredStakeToken = address(0);
        _prepare();
        vm.expectRevert(abi.encodeWithSelector(DeployPayerCampaign.StakeTokenIsNotThePoolQuote.selector, address(0)));
        script.preflight(); // the rule cannot measure ETH against a USDC pool, so it is refused unless allowed

        allowAboveRule = true;
        _prepare();
        script.preflight();
    }

    function test_aCampaignDurationMustOutlastTheTradingPhase() public {
        upDownDuration = upDownTrading; // would end before the first Round is over
        _prepare();
        vm.expectRevert(
            abi.encodeWithSelector(
                DeployPayerCampaign.InvalidConfig.selector, DeployPayerCampaign.ConfigField.UpDownDuration
            )
        );
        script.preflight();
    }
}

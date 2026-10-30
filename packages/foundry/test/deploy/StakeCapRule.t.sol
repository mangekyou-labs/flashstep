// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StakeCapRule } from "../../script/lib/StakeCapRule.sol";

/// @dev Expected values come from an independent floating-point evaluation of the derivation in
/// docs/implementation/payer-deploy.md (Python, run by hand, not the library's fixed-point path):
///   var(W, L) = W - L/3                      when W >= L
///             = W^2 (L - W/3) / L^2          when W <  L
///   r = 2 * sigma * sqrt(var)                (Reading shift that beats the natural drift)
///   d = r * L / min(W, L)                    (spot push, held min(W, L) seconds, to move the Reading by r)
///   n = ceil(min(W, L) / 2)                  (2 second blocks the push is held)
///   t = depth * d / 2,  cost = n * t * (2 * fee + d / 2),  cap = cost / 4,  sigma = 1e-4 per sqrt(second).
contract StakeCapRuleTest is Test {
    uint256 internal constant USDC_DEPTH = 13_633_808_211_200; // 13,633,808.2112 USDC at Base block 35,000,000

    function test_thirtySecondWindowOnTheDatedPoolAllowsAbout33USDC() public pure {
        uint256 cap = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        assertApproxEqRel(cap, 33_089_948, 1e15); // 33.09 USDC, within 0.1%
    }

    function test_shorterWindowsGiveALowerCap() public pure {
        uint256 w30 = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        uint256 w10 = StakeCapRule.maxStakeCap(USDC_DEPTH, 10, 30, 500);
        uint256 w6 = StakeCapRule.maxStakeCap(USDC_DEPTH, 6, 30, 500);
        uint256 w2 = StakeCapRule.maxStakeCap(USDC_DEPTH, 2, 30, 500);
        assertApproxEqRel(w10, 13_345_188, 1e15);
        assertApproxEqRel(w6, 8_273_850, 1e15);
        assertApproxEqRel(w2, 2_845_839, 1e15);
        assertLt(w2, w6);
        assertLt(w6, w10);
        assertLt(w10, w30);
    }

    function test_aLongerLookbackDilutesTheWindowPushSoTheCapGrows() public pure {
        assertApproxEqRel(StakeCapRule.maxStakeCap(USDC_DEPTH, 2, 4, 500), 735_910, 1e15);
        assertApproxEqRel(StakeCapRule.maxStakeCap(USDC_DEPTH, 2, 10, 500), 1_359_421, 1e15);
        assertApproxEqRel(StakeCapRule.maxStakeCap(USDC_DEPTH, 2, 60, 500), 4_647_815, 1e15);
        assertApproxEqRel(StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 60, 500), 61_715_484, 1e15);
    }

    function test_theDerivedMovesForALookbackOf30() public pure {
        // 30 second Window: the Reading must move 0.0894% and the held push is the same size.
        assertApproxEqRel(StakeCapRule.readingMove(30, 30), 0.00089443e18, 1e15);
        assertApproxEqRel(StakeCapRule.spotPush(30, 30), 0.00089443e18, 1e15);
        // 2 second Window: only 2 of the 30 lookback seconds carry the push, so the spot push is 15x the Reading shift.
        assertApproxEqRel(StakeCapRule.readingMove(2, 30), 0.00007221e18, 1e15);
        assertApproxEqRel(StakeCapRule.spotPush(2, 30), 0.00108321e18, 1e15);
        assertEq(StakeCapRule.holdBlocks(30, 30), 15);
        assertEq(StakeCapRule.holdBlocks(2, 30), 1);
        assertEq(StakeCapRule.holdBlocks(30, 10), 5, "a Window longer than the lookback holds only lookback seconds");
        assertEq(StakeCapRule.holdBlocks(7, 30), 4, "a partial block counts as a block");
    }

    function test_capScalesWithPoolDepth() public pure {
        uint256 full = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        uint256 half = StakeCapRule.maxStakeCap(USDC_DEPTH / 2, 30, 30, 500);
        assertApproxEqRel(half, 16_544_974, 1e15);
        assertLt(half, full);
    }

    function test_emptyPoolZeroWindowOrZeroLookbackGivesZero() public pure {
        assertEq(StakeCapRule.maxStakeCap(0, 30, 30, 500), 0);
        assertEq(StakeCapRule.maxStakeCap(USDC_DEPTH, 0, 30, 500), 0);
        assertEq(StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 0, 500), 0);
    }

    function test_hugeDepthDoesNotOverflow() public pure {
        // 1e30 raw units of depth must still compute, and stay under the contracts' 1e30 cap bound.
        uint256 cap = StakeCapRule.maxStakeCap(1e30, 30, 30, 500);
        assertApproxEqRel(cap, 2.427050983e24, 1e15);
        assertLt(cap, 1e30);
    }
}

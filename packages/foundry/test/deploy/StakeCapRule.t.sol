// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StakeCapRule } from "../../script/lib/StakeCapRule.sol";

/// @dev Expected values come from an independent floating-point evaluation of the documented formula
/// (Python, run by hand): cost = t * (2 * fee + m / 2), m = sigma * sqrt(W) * L / 2, t = depth * m / 2,
/// sigma = 1e-4 per sqrt(second), cap = cost / 4. They are not recomputed by the library's own code path.
contract StakeCapRuleTest is Test {
    uint256 internal constant USDC_DEPTH = 13_633_808_211_200; // 13,633,808.2112 USDC at Base block 35,000,000

    function test_thirtySecondWindowOnTheDatedPoolAllowsAbout71USDC() public pure {
        uint256 cap = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        assertApproxEqRel(cap, 71_519_274, 1e15); // 71.52 USDC, within 0.1%
    }

    function test_shorterWindowsGiveALowerCap() public pure {
        uint256 w30 = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        uint256 w10 = StakeCapRule.maxStakeCap(USDC_DEPTH, 10, 30, 500);
        uint256 w6 = StakeCapRule.maxStakeCap(USDC_DEPTH, 6, 30, 500);
        uint256 w2 = StakeCapRule.maxStakeCap(USDC_DEPTH, 2, 30, 500);
        assertApproxEqRel(w10, 27_256_397, 1e15);
        assertApproxEqRel(w6, 17_765_252, 1e15);
        assertApproxEqRel(w2, 7_449_718, 1e15);
        assertLt(w2, w6);
        assertLt(w6, w10);
        assertLt(w10, w30);
    }

    function test_capScalesWithPoolDepth() public pure {
        uint256 full = StakeCapRule.maxStakeCap(USDC_DEPTH, 30, 30, 500);
        uint256 half = StakeCapRule.maxStakeCap(USDC_DEPTH / 2, 30, 30, 500);
        assertApproxEqRel(half * 2, full, 1e15);
    }

    function test_emptyPoolOrZeroWindowGivesZero() public pure {
        assertEq(StakeCapRule.maxStakeCap(0, 30, 30, 500), 0);
        assertEq(StakeCapRule.maxStakeCap(USDC_DEPTH, 0, 30, 500), 0);
    }

    function test_hugeDepthDoesNotOverflow() public pure {
        // 1e30 raw units of depth must still compute, and stay under the contracts' 1e30 cap bound.
        uint256 cap = StakeCapRule.maxStakeCap(1e30, 30, 30, 500);
        assertGt(cap, 0);
        assertLt(cap, 1e30);
    }
}

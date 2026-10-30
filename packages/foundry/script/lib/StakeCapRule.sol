// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice The Stake cap rule of thumb, as arithmetic. The derivation is in docs/implementation/payer-deploy.md.
/// @dev A Round is decided by two geometric TWAP Readings (BasePoolReader): one at the start of the Window and
/// one at its end, each averaging the log price over the last `lookback` seconds. The worst case is one address
/// that stakes the cap on one side and also pushes the pool.
///   var    = W - L/3 when W >= L, else W^2 (L - W/3) / L^2: the variance, in sigma^2 seconds, of the difference
///            of two lookback averages W seconds apart, for a driftless random walk of the log price.
///   r      = NOISE_MULTIPLE * sigma * sqrt(var): the Reading shift that beats the natural difference.
///   h      = min(W, L): the seconds a push made after the start Reading can sit inside the end Reading's lookback.
///   d      = r * L / h: the spot push that, held h seconds, moves a Reading averaged over L seconds by r. A longer
///            lookback dilutes the same push, so it needs a bigger d.
///   n      = ceil(h / BLOCK_SECONDS): the blocks the push is held. Arbitrageurs undo it every block, so the pusher
///            pays again each block.
///   t      = depth * d / 2: the quote token volume that moves a constant product pool by d.
///   cost   = n * t * (2 * fee + d / 2): fees in and out plus average slippage, paid once per held block.
///   cap    = cost / SAFETY_DIVISOR: the Stake cap may not exceed a quarter of what moving the Reading costs.
/// A shorter Window holds the push for fewer blocks, so the cost and the cap fall: shorter Windows mean a lower
/// cap. Sigma is an assumption, not a measurement: see the runbook for what the fork test does and does not check.
library StakeCapRule {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant SIGMA = 1e14; // 1e-4 per sqrt(second), in 1e18 fixed point
    uint256 internal constant NOISE_MULTIPLE = 2; // push must beat two standard deviations of natural drift
    uint256 internal constant BLOCK_SECONDS = 2; // Base block time, same as the Round contracts' BLOCK_INTERVAL
    uint256 internal constant FEE_DENOMINATOR = 1_000_000; // Uniswap V3 fee units: 500 = 0.05%
    uint256 internal constant SAFETY_DIVISOR = 4;

    /// @return the relative change of the Reading (1e18 = 100%) a pusher must cause to beat the natural drift.
    function readingMove(uint256 windowSeconds, uint256 lookbackSeconds) internal pure returns (uint256) {
        uint256 variance; // in seconds, 1e18 fixed point
        if (windowSeconds >= lookbackSeconds) {
            variance = (3 * windowSeconds - lookbackSeconds) * ONE / 3;
        } else {
            variance = windowSeconds * windowSeconds * (3 * lookbackSeconds - windowSeconds) * ONE
                / (3 * lookbackSeconds * lookbackSeconds);
        }
        return NOISE_MULTIPLE * SIGMA * Math.sqrt(variance * ONE) / ONE;
    }

    /// @return the relative spot price push (1e18 = 100%), held for the whole Window or lookback, that causes
    /// `readingMove`.
    function spotPush(uint256 windowSeconds, uint256 lookbackSeconds) internal pure returns (uint256) {
        return readingMove(windowSeconds, lookbackSeconds) * lookbackSeconds / Math.min(windowSeconds, lookbackSeconds);
    }

    /// @return the number of blocks the push must be held, at least one.
    function holdBlocks(uint256 windowSeconds, uint256 lookbackSeconds) internal pure returns (uint256) {
        return Math.ceilDiv(Math.min(windowSeconds, lookbackSeconds), BLOCK_SECONDS);
    }

    /// @param poolDepth quote token held by the pool, in the stake token's raw units.
    /// @param windowSeconds the Round's Window.
    /// @param lookbackSeconds the Reading's averaging lookback.
    /// @param poolFee Uniswap V3 fee tier in hundredths of a basis point.
    /// @return the largest per-address, per-Round Stake cap the rule allows, in raw stake token units.
    function maxStakeCap(uint256 poolDepth, uint256 windowSeconds, uint256 lookbackSeconds, uint24 poolFee)
        internal
        pure
        returns (uint256)
    {
        if (poolDepth == 0 || windowSeconds == 0 || lookbackSeconds == 0) return 0;
        uint256 push = spotPush(windowSeconds, lookbackSeconds);
        uint256 volume = poolDepth * push / 2 / ONE; // t, raw units
        uint256 feeAndSlip = uint256(poolFee) * 2 * ONE / FEE_DENOMINATOR + push / 2; // 1e18
        uint256 cost = holdBlocks(windowSeconds, lookbackSeconds) * volume * feeAndSlip / ONE;
        return cost / SAFETY_DIVISOR;
    }
}

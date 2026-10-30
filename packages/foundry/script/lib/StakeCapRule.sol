// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @notice The Stake cap rule of thumb, as arithmetic. See docs/implementation/payer-deploy.md.
/// @dev Model of the worst case for one address that stakes the cap on the losing side and also pushes the pool:
///   sigma  = 1e-4 per sqrt(second): assumed volatility of the pool price, a deliberately generous figure.
///   m      = sigma * sqrt(Window) * lookback / 2: the relative move a Window-long push can leave in the
///            lookback-averaged Reading.
///   t      = depth * m / 2: the quote-token volume the pool needs to move its price by m (constant product
///            pool, depth = quote token held by the pool).
///   cost   = t * (2 * fee + m / 2): swap fees both ways plus the average slippage on the way in, paid by the
///            pusher to hold the move.
///   cap    = cost / 4: the Stake cap may not exceed a quarter of what moving the Reading costs, so pushing the
///            Reading never pays for itself even if the pusher wins the whole Pot at the cap.
/// A shorter Window shrinks sqrt(Window), so m, t and the cost all fall: shorter Windows mean a lower cap.
library StakeCapRule {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant SIGMA = 1e14; // 1e-4 in 1e18 fixed point
    uint256 internal constant FEE_DENOMINATOR = 1_000_000; // Uniswap V3 fee units: 500 = 0.05%
    uint256 internal constant SAFETY_DIVISOR = 4;

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
        if (poolDepth == 0 || windowSeconds == 0) return 0;
        uint256 sqrtWindow = Math.sqrt(windowSeconds * ONE * ONE); // sqrt(W) in 1e18
        uint256 move = SIGMA * sqrtWindow / ONE * lookbackSeconds / 2; // m in 1e18
        uint256 volume = poolDepth * move / 2 / ONE; // t, raw units
        uint256 feeAndSlip = uint256(poolFee) * 2 * ONE / FEE_DENOMINATOR + move / 2; // 1e18
        return volume * feeAndSlip / ONE / SAFETY_DIVISOR;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice The Uniswap v3 pool surface used by the shared Reading module.
interface IObservationPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IObservationPool } from "../../contracts/readings/IObservationPool.sol";

/// @notice Script a pool's tick at the current vm.warp/vm.roll endpoint.
/// Each tick applies until the next write, matching v3's time-weighted accumulation.
contract MockBasePool is IObservationPool {
    struct Observation {
        uint256 blockNumber;
        uint256 timestamp;
        int56 cumulative;
        int24 tick;
    }

    address public immutable token0;
    address public immutable token1;
    Observation[] public observations;
    bool public missing;
    mapping(uint256 => bool) public missingAtBlock;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setMissing(bool missing_) external {
        missing = missing_;
    }

    /// @notice Make observe() fail only while executing in `blockNumber`, e.g. a missed boundary capture.
    function setMissingAtBlock(uint256 blockNumber, bool missing_) external {
        missingAtBlock[blockNumber] = missing_;
    }

    function write(int24 tick) external {
        require(tick >= -887272 && tick <= 887272, "tick");
        int56 cumulative;
        if (observations.length != 0) {
            Observation memory last = observations[observations.length - 1];
            require(block.number >= last.blockNumber && block.timestamp >= last.timestamp, "time moved backwards");
            cumulative = last.cumulative + int56(last.tick) * int56(uint56(block.timestamp - last.timestamp));
        }
        observations.push(Observation(block.number, block.timestamp, cumulative, tick));
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory cumulatives, uint160[] memory liquidities)
    {
        require(!missing && !missingAtBlock[block.number] && observations.length != 0, "OLD");
        cumulatives = new int56[](secondsAgos.length);
        liquidities = new uint160[](secondsAgos.length);
        for (uint256 i; i < secondsAgos.length; ++i) {
            require(secondsAgos[i] <= block.timestamp, "OLD");
            uint256 target = block.timestamp - secondsAgos[i];
            require(target >= observations[0].timestamp, "OLD");
            for (uint256 j = observations.length; j > 0; --j) {
                Observation memory observation = observations[j - 1];
                if (observation.timestamp <= target) {
                    cumulatives[i] = observation.cumulative + int56(observation.tick)
                        * int56(uint56(target - observation.timestamp));
                    break;
                }
            }
        }
    }
}

/// @notice Mutable supply fixture without token-transfer behavior irrelevant to Readings.
contract MockReadingToken {
    uint8 public immutable decimals;
    uint256 public totalSupply;

    constructor(uint8 decimals_, uint256 supply_) {
        decimals = decimals_;
        totalSupply = supply_;
    }

    function setTotalSupply(uint256 supply) external {
        totalSupply = supply;
    }
}

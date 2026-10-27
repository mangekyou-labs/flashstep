// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IObservationPool } from "./IObservationPool.sol";
import { TickMath } from "./TickMath.sol";

/// @notice Captures block-pinned Uniswap v3 geometric TWAP Readings for both Round contracts.
/// @dev This module captures prices only. MarketCapReader resolves eligible supply after the
/// endpoint block has ended. Missing boundary captures must cause the consuming Round to refund.
contract BasePoolReader {
    error InvalidConfiguration();
    error NoValidReading();

    struct Reading {
        uint256 blockNumber;
        uint256 timestamp;
        uint256 price; // Whole quote tokens per whole base token, scaled by PRICE_SCALE.
    }

    /// @notice Shortest lookback spanning more than one 2-second Base block.
    uint32 public constant MIN_LOOKBACK = 4;
    /// @notice Longest supported lookback; initial Campaigns use 30 seconds.
    uint32 public constant MAX_LOOKBACK = 60;
    /// @notice Fixed-point scale of Reading prices, so prices below 1e-18 still resolve and compare.
    uint256 public constant PRICE_SCALE = 1e36;

    IObservationPool public immutable pool;
    IERC20Metadata public immutable token;
    address public immutable quoteToken;
    uint32 public immutable lookback;
    uint256 public immutable tokenUnit;
    uint256 public immutable quoteUnit;
    bool public immutable tokenIsToken0;
    /// @dev PRICE_SCALE * tokenUnit / quoteUnit: always an integer between 1e18 and 1e54.
    uint256 private immutable rawPriceScale;
    mapping(uint256 => Reading) private readings;

    event ReadingCaptured(uint256 indexed blockNumber, uint256 timestamp, uint256 price);

    constructor(address pool_, address token_, uint32 lookback_) {
        if (lookback_ < MIN_LOOKBACK || lookback_ > MAX_LOOKBACK) {
            revert InvalidConfiguration();
        }
        pool = IObservationPool(pool_);
        token = IERC20Metadata(token_);
        lookback = lookback_;
        address token0 = pool.token0();
        address token1 = pool.token1();
        if (token0 == token1 || (token_ != token0 && token_ != token1)) revert InvalidConfiguration();
        tokenIsToken0 = token_ == token0;
        quoteToken = tokenIsToken0 ? token1 : token0;
        uint8 baseDecimals = token.decimals();
        uint8 quoteDecimals = IERC20Metadata(quoteToken).decimals();
        if (baseDecimals > 18 || quoteDecimals > 18) revert InvalidConfiguration();
        tokenUnit = 10 ** baseDecimals;
        quoteUnit = 10 ** quoteDecimals;
        rawPriceScale = 10 ** (36 + uint256(baseDecimals) - quoteDecimals);
    }

    /// @notice First capture in a block wins; every subsequent call returns that exact Reading.
    function capture() external returns (Reading memory reading) {
        reading = readings[block.number];
        if (reading.timestamp != 0) return reading;
        if (block.timestamp < lookback) revert NoValidReading();
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = lookback;
        int56[] memory cumulatives;
        try pool.observe(secondsAgos) returns (int56[] memory values, uint160[] memory liquidities) {
            if (values.length != 2 || liquidities.length != 2) revert NoValidReading();
            cumulatives = values;
        } catch {
            revert NoValidReading();
        }
        int56 delta;
        unchecked {
            delta = cumulatives[1] - cumulatives[0];
        }
        int56 mean = delta / int56(uint56(lookback));
        if (delta < 0 && delta % int56(uint56(lookback)) != 0) --mean;
        if (mean < TickMath.MIN_TICK || mean > TickMath.MAX_TICK) revert NoValidReading();
        uint160 sqrtRatio = TickMath.getSqrtRatioAtTick(int24(mean));
        uint256 price;
        if (sqrtRatio <= type(uint128).max) {
            uint256 ratio = uint256(sqrtRatio) * sqrtRatio;
            price = tokenIsToken0 ? _mulDiv(ratio, rawPriceScale, 1 << 192) : _mulDiv(1 << 192, rawPriceScale, ratio);
        } else {
            uint256 ratio = Math.mulDiv(sqrtRatio, sqrtRatio, 1 << 64);
            price = tokenIsToken0 ? _mulDiv(ratio, rawPriceScale, 1 << 128) : _mulDiv(1 << 128, rawPriceScale, ratio);
        }
        if (price == 0) revert NoValidReading();
        reading = Reading(block.number, block.timestamp, price);
        readings[block.number] = reading;
        emit ReadingCaptured(block.number, block.timestamp, price);
    }

    /// @notice Read a previously captured endpoint; no extrapolation or latest-price fallback.
    function read(uint256 endBlock) external view returns (Reading memory reading) {
        reading = readings[endBlock];
        if (reading.timestamp == 0 || endBlock > block.number) revert NoValidReading();
    }

    /// @dev Math.mulDiv panics when the result exceeds uint256; at extreme ticks that is no Reading.
    function _mulDiv(uint256 x, uint256 y, uint256 denominator) private pure returns (uint256) {
        (uint256 high,) = Math.mul512(x, y);
        if (high >= denominator) revert NoValidReading();
        return Math.mulDiv(x, y, denominator);
    }
}

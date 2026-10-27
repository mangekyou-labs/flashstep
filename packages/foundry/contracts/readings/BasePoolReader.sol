// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IObservationPool } from "./IObservationPool.sol";
import { TickMath } from "./TickMath.sol";

/// @notice Captures block-pinned Uniswap v3 geometric TWAP Readings for both Round contracts.
/// @dev Supply is sampled at capture execution. A standard ERC-20 cannot prove historical or
/// finalized end-of-block supply. Missing boundary captures must cause the consuming Round to refund.
contract BasePoolReader {
    error InvalidConfiguration();
    error NoValidReading();

    struct Reading {
        uint256 blockNumber;
        uint256 timestamp;
        uint256 price; // Quote tokens per whole base token, scaled by 1e18.
        uint256 totalSupply; // Raw base-token units at capture execution.
        uint256 marketCap; // Quote tokens, scaled by 1e18.
    }

    IObservationPool public immutable pool;
    IERC20Metadata public immutable token;
    address public immutable quoteToken;
    uint32 public immutable lookback;
    uint256 public immutable tokenUnit;
    uint256 public immutable quoteUnit;
    bool public immutable tokenIsToken0;
    mapping(uint256 => Reading) private readings;

    event ReadingCaptured(
        uint256 indexed blockNumber, uint256 timestamp, uint256 price, uint256 totalSupply, uint256 marketCap
    );

    constructor(address pool_, address token_, uint32 lookback_) {
        if ((block.chainid != 8453 && block.chainid != 84532) || lookback_ < 4 || lookback_ > 30) {
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
    }

    /// @notice First capture in a block wins; every subsequent call returns that exact Reading.
    function capture() external returns (Reading memory reading) {
        reading = readings[block.number];
        if (reading.timestamp != 0) return reading;
        if ((block.chainid != 8453 && block.chainid != 84532) || block.timestamp < lookback) revert NoValidReading();
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
        if (mean < -887272 || mean > 887272) revert NoValidReading();
        uint160 sqrtRatio = TickMath.getSqrtRatioAtTick(int24(mean));
        uint256 rawQuote;
        if (sqrtRatio <= type(uint128).max) {
            uint256 ratio = uint256(sqrtRatio) * sqrtRatio;
            rawQuote = tokenIsToken0
                ? Math.mulDiv(ratio, tokenUnit * 1e18, 1 << 192)
                : Math.mulDiv(1 << 192, tokenUnit * 1e18, ratio);
        } else {
            uint256 ratio = Math.mulDiv(sqrtRatio, sqrtRatio, 1 << 64);
            rawQuote = tokenIsToken0
                ? Math.mulDiv(ratio, tokenUnit * 1e18, 1 << 128)
                : Math.mulDiv(1 << 128, tokenUnit * 1e18, ratio);
        }
        uint256 price = rawQuote / quoteUnit;
        if (price == 0) revert NoValidReading();
        uint256 supply;
        try token.totalSupply() returns (uint256 value) {
            supply = value;
        } catch {
            revert NoValidReading();
        }
        reading = Reading(block.number, block.timestamp, price, supply, Math.mulDiv(price, supply, tokenUnit));
        readings[block.number] = reading;
        emit ReadingCaptured(block.number, block.timestamp, price, supply, reading.marketCap);
    }

    /// @notice Read a previously captured endpoint; no extrapolation or latest-price fallback.
    function read(uint256 endBlock) external view returns (Reading memory reading) {
        reading = readings[endBlock];
        if (reading.timestamp == 0 || endBlock > block.number) revert NoValidReading();
    }
}

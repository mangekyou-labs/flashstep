// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockReadingToken } from "../mocks/MockBasePool.sol";

/// @notice Serves one scripted Reading so market-cap math can be fuzzed over any uint256 price.
contract StubPriceReader {
    address public immutable i_baseToken;
    uint256 public immutable i_baseUnit;
    BasePoolReader.Reading internal s_reading;

    constructor(address baseToken_, uint256 baseUnit_, BasePoolReader.Reading memory reading_) {
        i_baseToken = baseToken_;
        i_baseUnit = baseUnit_;
        s_reading = reading_;
    }

    function read(uint256 endBlock) external view returns (BasePoolReader.Reading memory) {
        require(endBlock == s_reading.blockNumber, "uncaptured");
        return s_reading;
    }
}

contract MarketCapReaderFuzzTest is Test {
    function setUp() public {
        vm.roll(500);
        vm.warp(1_000);
    }

    /// Any price and supply over the full uint256 range.
    function testFuzzMarketCapIsExactProductOrNoValidMarketCap(
        uint256 priceSeed,
        uint256 supplySeed,
        uint256 decimalsSeed
    ) public {
        _checkMarketCap(bound(priceSeed, 1, type(uint256).max), bound(supplySeed, 1, type(uint256).max), decimalsSeed);
    }

    /// Shifted magnitudes, so products land on both sides of the uint256 limit rather than mostly far above it.
    function testFuzzMarketCapNearTheOverflowLimit(
        uint256 priceSeed,
        uint256 priceShift,
        uint256 supplySeed,
        uint256 supplyShift,
        uint256 decimalsSeed
    ) public {
        uint256 price = bound(priceSeed, 1, type(uint256).max) >> bound(priceShift, 0, 255);
        uint256 supply = bound(supplySeed, 1, type(uint256).max) >> bound(supplyShift, 0, 255);
        _checkMarketCap(price == 0 ? 1 : price, supply == 0 ? 1 : supply, decimalsSeed);
    }

    function testMarketCapAtTheExactUint256Limit() public {
        // price × supply / 1 == type(uint256).max fits; one more base unit of product does not.
        _checkMarketCap(type(uint256).max, 1, 0);
        _expectNoValidMarketCap(type(uint256).max, 2, 0);
    }

    function _checkMarketCap(uint256 price, uint256 supply, uint256 decimalsSeed) internal {
        uint8 decimals = uint8(bound(decimalsSeed, 0, 18));
        (bool fits, uint256 expected) = _referenceMarketCap(price, supply, 10 ** decimals);
        MarketCapReader caps = _caps(price, supply, decimals);
        if (!fits) {
            vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
            caps.readMarketCap(499);
            return;
        }
        MarketCapReader.MarketCapReading memory reading = caps.readMarketCap(499);
        assertEq(reading.marketCap, expected);
        assertEq(reading.totalSupply, supply);
        assertEq(reading.reading.price, price);
    }

    function _expectNoValidMarketCap(uint256 price, uint256 supply, uint8 decimals) internal {
        MarketCapReader caps = _caps(price, supply, decimals);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        caps.readMarketCap(499);
    }

    function _caps(uint256 price, uint256 supply, uint8 decimals) internal returns (MarketCapReader) {
        MockReadingToken token = new MockReadingToken(decimals, supply);
        StubPriceReader stub =
            new StubPriceReader(address(token), 10 ** decimals, BasePoolReader.Reading(499, 998, price));
        return new MarketCapReader(BasePoolReader(address(stub)), MarketCapReader.SupplyMode.Fixed, supply);
    }

    /// @dev floor(p × s / u) without 512-bit math. With s = sQ·u + sR and p = pQ·u + pR:
    /// floor(p × s / u) = p·sQ + pQ·sR + floor(pR·sR / u), where pR·sR < u² ≤ 1e36 cannot overflow.
    /// Every other term and sum is overflow-checked by division, not by the reader's mul512 path.
    function _referenceMarketCap(uint256 p, uint256 s, uint256 u) internal pure returns (bool fits, uint256 result) {
        uint256 sQ = s / u;
        uint256 sR = s % u;
        uint256 pQ = p / u;
        uint256 pR = p % u;
        uint256 max = type(uint256).max;
        if (sQ != 0 && p > max / sQ) return (false, 0);
        uint256 first = p * sQ;
        if (sR != 0 && pQ > max / sR) return (false, 0);
        uint256 second = pQ * sR;
        uint256 third = (pR * sR) / u;
        if (first > max - second) return (false, 0);
        result = first + second;
        if (result > max - third) return (false, 0);
        return (true, result + third);
    }
}

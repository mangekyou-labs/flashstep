// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ThresholdSupplyToken is ERC20Votes {
    constructor() ERC20("Threshold supply", "THR") EIP712("Threshold supply", "1") {
        _mint(msg.sender, 1_000 ether);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

contract ThresholdPotsMarketCapTest is StakeTestBase {
    ThresholdSupplyToken token;
    MockBasePool pool;
    BasePoolReader reader;
    ThresholdPots market;

    function setUp() public virtual {
        _initStakeToken();
        vm.warp(100);
        vm.roll(10);
        token = new ThresholdSupplyToken();
        MockReadingToken quote = new MockReadingToken(18, 0);
        pool = new MockBasePool(address(token), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(token), 4);
        market = _newThreshold(address(this), reader);
        _deal(address(this), 10 ether);
        market.fund{ value: _value(2 ether) }(2 ether);
    }

    function settings(MarketCapReader caps, uint256 threshold)
        internal
        view
        returns (ThresholdPots.CampaignSettings memory)
    {
        return ThresholdPots.CampaignSettings({
            openingStake: 1 ether,
            stakeCap: 1 ether,
            threshold: threshold,
            tradingSeconds: 10,
            windowSeconds: 4,
            endTime: 200,
            metric: ThresholdPots.Metric.MarketCap,
            reader: reader,
            marketCapReader: caps
        });
    }

    function testUnsupportedSupplyCannotCreateRoundOrConsumeOpeningFunding() public {
        MarketCapReader caps = new MarketCapReader(reader, MarketCapReader.SupplyMode.Unsupported, 0);
        vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
        market.seedRound(settings(caps, 1_000e36));
        assertEq(market.currentRound(), 0);
        assertEq(market.fundingBalance(), 2 ether);
        assertEq(market.reservedBalance(), 0);
    }

    function testMarketCapReaderFromAnotherPoolCannotCreateRound() public {
        BasePoolReader other = new BasePoolReader(address(pool), address(token), 6);
        MarketCapReader caps = new MarketCapReader(other, MarketCapReader.SupplyMode.Fixed, 1_000 ether);
        vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
        market.seedRound(settings(caps, 1_000e36));
        assertEq(market.fundingBalance(), 2 ether);
        assertEq(market.currentRound(), 0);
    }

    function testMarketCapUsesFinalEndBlockSupplyAndCannotSettleBeforeBlockCompletes() public {
        MarketCapReader caps = new MarketCapReader(reader, MarketCapReader.SupplyMode.Checkpoints, 0);
        market.seedRound(settings(caps, 1_500e36));
        vm.warp(114);
        vm.roll(17);
        token.mint(1_000_000 ether);
        market.captureBoundary(1);
        token.burn(1_000_000 ether);
        token.mint(500 ether);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        market.settle(1);
        vm.warp(116);
        vm.roll(18);
        token.mint(5_000 ether);
        market.settle(1);
        ThresholdPots.Round memory r = market.round(1);
        assertEq(uint256(r.result), uint256(ThresholdPots.Result.Tie));
        assertEq(r.endValue, 1_500e36);
        assertEq(r.totalSupply, 1_500 ether);
        assertEq(r.endReading.blockNumber, 17);
        assertEq(market.claimable(1, address(this)), 2 ether);
        market.claim(1);
        assertEq(_balance(address(market)), 0);
    }

    function testFixedSupplyTieUsesConfiguredHistoricalSupply() public {
        settleFixed(1_000e36, ThresholdPots.Result.Tie);
    }

    function testFixedSupplyOneAboveThresholdResolvesYes() public {
        settleFixed(1_000e36 - 1, ThresholdPots.Result.Yes);
    }

    function testFixedSupplyOneBelowThresholdResolvesNo() public {
        settleFixed(1_000e36 + 1, ThresholdPots.Result.No);
    }

    function settleFixed(uint256 threshold, ThresholdPots.Result expected) internal {
        MarketCapReader caps = new MarketCapReader(reader, MarketCapReader.SupplyMode.Fixed, 1_000 ether);
        market.seedRound(settings(caps, threshold));
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        market.settle(1);
        vm.warp(116);
        vm.roll(18);
        market.settle(1);
        ThresholdPots.Round memory r = market.round(1);
        assertEq(uint256(r.result), uint256(expected));
        assertEq(r.endValue, 1_000e36);
        assertEq(r.totalSupply, 1_000 ether);
        assertEq(r.endReading.blockNumber, 17);
        assertEq(r.endReading.price, 1e36);
        assertEq(market.claimable(1, address(this)), 2 ether);
        market.claim(1);
        assertEq(_balance(address(market)), 0);
    }

    receive() external payable { }
}

contract ThresholdPotsMarketCapTestERC20 is ThresholdPotsMarketCapTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

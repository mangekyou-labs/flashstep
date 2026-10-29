// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

abstract contract ThresholdFixture is StakeTestBase {
    ThresholdPots market;
    BasePoolReader reader;
    MarketCapReader capReader;
    MockBasePool pool;
    MockReadingToken base;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA201);

    function setUp() public virtual {
        _initStakeToken();
        vm.warp(100);
        vm.roll(10);
        base = new MockReadingToken(18, 100e18);
        MockReadingToken quoteToken = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quoteToken));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        capReader = new MarketCapReader(reader, MarketCapReader.SupplyMode.Fixed, 100e18);
        market = _newThreshold(address(this), reader);
        _deal(address(this), 100 ether);
        _deal(alice, 100 ether);
        _deal(bob, 100 ether);
        _deal(carol, 100 ether);
        market.fund{ value: _value(10 ether) }(10 ether);
    }

    function settings() internal view returns (ThresholdPots.CampaignSettings memory s) {
        s = ThresholdPots.CampaignSettings({
            openingStake: 1 ether,
            stakeCap: 10 ether,
            threshold: 1e36,
            tradingSeconds: 10,
            windowSeconds: 4,
            endTime: type(uint64).max,
            metric: ThresholdPots.Metric.Price,
            reader: reader,
            marketCapReader: MarketCapReader(address(0))
        });
    }

    function stakeAs(address who, uint256 id, ThresholdPots.Side side, uint256 amount) internal {
        vm.prank(who);
        market.stake{ value: _value(amount) }(id, side, amount);
    }

    function finish(uint256 id) internal {
        uint256 end = market.round(id).windowEnd;
        vm.warp(end);
        vm.roll(end / 2);
        market.captureBoundary(id);
        vm.warp(end + 2);
        vm.roll(end / 2 + 1);
        market.settle(id);
    }

    receive() external payable { }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";

contract ThresholdPotsForkTest is StakeTestBase {
    function testThresholdPotSettlesFromRealPinnedBasePool() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, 35_000_000);
        _initStakeToken();
        if (address(stakeToken) != address(0)) vm.makePersistent(address(stakeToken));
        BasePoolReader reader = new BasePoolReader(
            0xd0b53D9277642d899DF5C87A3966A349A798F224, 0x4200000000000000000000000000000000000006, 30
        );
        ThresholdPots market = _newThreshold(address(this), reader);
        vm.makePersistent(address(market), address(reader));
        _deal(address(this), 2 ether);
        market.fund{ value: _value(2 ether) }(2 ether);
        market.seedRound(
            ThresholdPots.CampaignSettings(
                1 ether,
                1 ether,
                4_500e36,
                10,
                4,
                uint64(block.timestamp + 10),
                ThresholdPots.Metric.Price,
                reader,
                MarketCapReader(address(0))
            )
        );
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        _deal(alice, 1 ether);
        _deal(bob, 1 ether);
        vm.prank(alice);
        market.stake{ value: _value(1 ether) }(1, ThresholdPots.Side.Yes, 1 ether);
        vm.prank(bob);
        market.stake{ value: _value(1 ether) }(1, ThresholdPots.Side.No, 1 ether);
        vm.rollFork(35_000_007);
        market.captureBoundary(1);
        vm.rollFork(35_000_010);
        market.settle(1);
        ThresholdPots.Round memory r = market.round(1);
        assertEq(r.endReading.blockNumber, 35_000_007);
        assertEq(r.endReading.timestamp, r.windowEnd);
        assertGt(r.endReading.price, 4_000e36);
        assertLt(r.endReading.price, 5_000e36);
        ThresholdPots.Result expected = r.endReading.price > 4_500e36
            ? ThresholdPots.Result.Yes
            : r.endReading.price < 4_500e36 ? ThresholdPots.Result.No : ThresholdPots.Result.Tie;
        assertEq(uint256(r.result), uint256(expected));
        uint256 aliceExpected =
            expected == ThresholdPots.Result.Yes ? 2 ether : expected == ThresholdPots.Result.Tie ? 1 ether : 0;
        uint256 bobExpected =
            expected == ThresholdPots.Result.No ? 2 ether : expected == ThresholdPots.Result.Tie ? 1 ether : 0;
        assertEq(market.claim(1), 2 ether);
        vm.prank(alice);
        assertEq(market.claim(1), aliceExpected);
        vm.prank(bob);
        assertEq(market.claim(1), bobExpected);
        assertEq(_balance(alice), aliceExpected);
        assertEq(_balance(bob), bobExpected);
        assertEq(_balance(address(market)), 0);
        assertEq(_balance(address(this)) + _balance(alice) + _balance(bob), 4 ether);
    }
    receive() external payable { }
}

contract ThresholdPotsForkTestERC20 is ThresholdPotsForkTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

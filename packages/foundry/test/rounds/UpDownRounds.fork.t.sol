// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";

contract UpDownRoundsForkTest is Test {
    function testRoundSettlesFromRealPinnedBasePool() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, 35_000_000);
        BasePoolReader reader = new BasePoolReader(
            0xd0b53D9277642d899DF5C87A3966A349A798F224, 0x4200000000000000000000000000000000000006, 30
        );
        UpDownRounds market = new UpDownRounds(address(this), reader);
        vm.makePersistent(address(market), address(reader));
        vm.deal(address(this), 1 ether);
        market.fund{ value: 1 ether }();
        market.seedRound(1 ether, 1 ether, 10, 4);
        address player = address(0xA11CE);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        vm.deal(player, cost);
        vm.prank(player);
        market.buy{ value: cost }(1, UpDownRounds.Side.Up, 1e18, cost);
        vm.rollFork(35_000_005);
        market.captureBoundary(1);
        vm.rollFork(35_000_007);
        market.captureBoundary(1);
        vm.rollFork(35_000_010);
        market.settle(1);
        UpDownRounds.Round memory r = market.round(1);
        assertEq(r.startReading.blockNumber, 35_000_005);
        assertEq(r.endReading.blockNumber, 35_000_007);
        assertGt(r.startReading.price, 4_000e36);
        assertLt(r.startReading.price, 5_000e36);
        assertGt(r.endReading.price, 4_000e36);
        assertLt(r.endReading.price, 5_000e36);
        uint256 expected = r.endReading.price > r.startReading.price
            ? 0.01 ether
            : r.endReading.price == r.startReading.price ? cost : 0;
        vm.prank(player);
        market.claim(1);
        assertEq(player.balance, expected);
        assertEq(address(market).balance + player.balance, 1 ether + cost);
    }
}

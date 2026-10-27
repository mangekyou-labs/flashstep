// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";

/// @notice Run explicitly with BASE_RPC_URL set to an archive-capable Base endpoint.
contract BasePoolReaderForkTest is Test {
    address internal constant POOL = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function testBaseUniswapV3ReadingAtPinnedMainnetBlock() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, 35_000_000);
        assertEq(block.chainid, 8453);
        assertEq(block.timestamp, 1_756_789_347);
        // At this historical endpoint, quote reserves alone exceed the spec's $100k floor.
        assertGt(IERC20(USDC).balanceOf(POOL), 100_000e6);

        BasePoolReader reader = new BasePoolReader(POOL, WETH, 30);
        BasePoolReader.Reading memory reading = reader.capture();
        assertEq(reading.blockNumber, 35_000_000);
        assertGt(reading.price, 4_000 ether);
        assertLt(reading.price, 5_000 ether);
        assertEq(reader.read(35_000_000).price, reading.price);
        emit log_named_uint("30-second WETH/USDC price (1e18)", reading.price);

        // Four seconds is the shortest supported multi-block lookback at two-second blocks.
        BasePoolReader shortest = new BasePoolReader(POOL, WETH, 4);
        assertGt(shortest.capture().price, 4_000 ether);
        assertLt(shortest.read(35_000_000).price, 5_000 ether);

        // Mutable WETH has no vetted block-number total-supply checkpoint interface here.
        MarketCapReader capReader = new MarketCapReader(reader, MarketCapReader.SupplyMode.Unsupported, 0);
        vm.roll(35_000_001);
        vm.expectRevert(MarketCapReader.NoValidMarketCap.selector);
        capReader.readMarketCap(35_000_000);
        assertEq(reader.read(35_000_000).price, reading.price);
    }
}

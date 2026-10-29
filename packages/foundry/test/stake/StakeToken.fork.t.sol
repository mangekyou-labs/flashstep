// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

interface IUSDCBlocklist {
    function blacklister() external view returns (address);
    function blacklist(address account) external;
    function unBlacklist(address account) external;
}

/// @notice Real native USDC custody; deterministic TWAPs isolate claim/refund behavior.
/// The earlier pool fork suites separately exercise real historical pool observations.
contract StakeTokenForkTest is Test {
    using SafeERC20 for IERC20;

    uint256 constant FORK_BLOCK = 35_000_000;
    IERC20 constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address constant HOLDER = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    BasePoolReader reader;
    MockBasePool pool;
    UpDownRounds upDown;
    ThresholdPots pots;
    uint256 start;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, FORK_BLOCK);
        assertEq(block.chainid, 8453);
        assertGt(address(USDC).code.length, 0);
        assertEq(IERC20Metadata(address(USDC)).symbol(), "USDC");
        assertEq(IERC20Metadata(address(USDC)).decimals(), 6);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quote = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        upDown = new UpDownRounds(address(this), reader, address(USDC), 10_000);
        pots = new ThresholdPots(address(this), reader, address(USDC));
        vm.startPrank(HOLDER);
        USDC.safeTransfer(address(this), 20_000_000);
        USDC.safeTransfer(ALICE, 2_000_000);
        USDC.safeTransfer(BOB, 2_000_000);
        vm.stopPrank();
        USDC.forceApprove(address(upDown), 10_000_000);
        USDC.forceApprove(address(pots), 10_000_000);
        upDown.fund(10_000_000);
        pots.fund(10_000_000);
        upDown.seedRound(1_000_000, 1_000_000, 10, 4);
        pots.seedRound(
            ThresholdPots.CampaignSettings(
                100_000,
                1_000_000,
                1e36,
                10,
                4,
                uint64(block.timestamp + 10),
                ThresholdPots.Metric.Price,
                reader,
                MarketCapReader(address(0))
            )
        );
        vm.startPrank(ALICE);
        USDC.forceApprove(address(upDown), 1_000_000);
        USDC.forceApprove(address(pots), 1_000_000);
        vm.stopPrank();
        vm.startPrank(BOB);
        USDC.forceApprove(address(upDown), 1_000_000);
        USDC.forceApprove(address(pots), 1_000_000);
        vm.stopPrank();
        start = block.timestamp;
    }

    function _buy(address player) private returns (uint256 cost) {
        cost = upDown.quote(1, UpDownRounds.Side.Up, 1e18);
        vm.prank(player);
        upDown.buy(1, UpDownRounds.Side.Up, 1e18, cost);
    }

    function _finish(int24 tick) private {
        vm.warp(start + 10);
        vm.roll(FORK_BLOCK + 5);
        upDown.captureBoundary(1);
        pool.write(tick);
        vm.warp(start + 14);
        vm.roll(FORK_BLOCK + 7);
        upDown.captureBoundary(1);
        pots.captureBoundary(1);
        vm.warp(start + 16);
        vm.roll(FORK_BLOCK + 8);
        upDown.settle(1);
        pots.settle(1);
    }

    function testRealUSDCUpDownWinningClaim() public {
        _buy(ALICE);
        _finish(100);
        assertEq(uint256(upDown.round(1).result), uint256(UpDownRounds.Result.Up));
        uint256 before = USDC.balanceOf(ALICE);
        vm.prank(ALICE);
        assertEq(upDown.claim(1), 10_000);
        assertEq(USDC.balanceOf(ALICE) - before, 10_000);
        vm.prank(ALICE);
        assertEq(upDown.claim(1), 0);
    }

    function testRealUSDCUpDownTieRefund() public {
        uint256 before = USDC.balanceOf(ALICE);
        uint256 cost = _buy(ALICE);
        _finish(0);
        assertEq(uint256(upDown.round(1).result), uint256(UpDownRounds.Result.Tie));
        vm.prank(ALICE);
        assertEq(upDown.claim(1), cost);
        assertEq(USDC.balanceOf(ALICE), before);
    }

    function testRealUSDCThresholdWinningClaim() public {
        vm.prank(ALICE);
        pots.stake(1, ThresholdPots.Side.Yes, 100_000);
        vm.prank(BOB);
        pots.stake(1, ThresholdPots.Side.No, 100_000);
        _finish(100);
        assertEq(uint256(pots.round(1).result), uint256(ThresholdPots.Result.Yes));
        uint256 before = USDC.balanceOf(ALICE);
        vm.prank(ALICE);
        assertEq(pots.claim(1), 200_000);
        assertEq(USDC.balanceOf(ALICE) - before, 200_000);
    }

    function testRealUSDCThresholdTieRefund() public {
        uint256 before = USDC.balanceOf(ALICE);
        vm.prank(ALICE);
        pots.stake(1, ThresholdPots.Side.Yes, 100_000);
        _finish(0);
        assertEq(uint256(pots.round(1).result), uint256(ThresholdPots.Result.Tie));
        vm.prank(ALICE);
        assertEq(pots.claim(1), 100_000);
        assertEq(USDC.balanceOf(ALICE), before);
    }

    function testRealUSDCBlockedPlayerCannotStopOtherClaims() public {
        _buy(ALICE);
        _buy(BOB);
        vm.prank(ALICE);
        pots.stake(1, ThresholdPots.Side.Yes, 100_000);
        vm.prank(BOB);
        pots.stake(1, ThresholdPots.Side.Yes, 100_000);
        _finish(100);
        IUSDCBlocklist control = IUSDCBlocklist(address(USDC));
        address blacklister = control.blacklister();
        vm.prank(blacklister);
        control.blacklist(ALICE);
        uint256 upClaim = upDown.claimable(1, ALICE);
        uint256 potClaim = pots.claimable(1, ALICE);
        vm.expectRevert();
        vm.prank(ALICE);
        upDown.claim(1);
        vm.expectRevert();
        vm.prank(ALICE);
        pots.claim(1);
        assertEq(upDown.claimable(1, ALICE), upClaim);
        assertEq(pots.claimable(1, ALICE), potClaim);
        uint256 before = USDC.balanceOf(BOB);
        vm.prank(BOB);
        assertEq(upDown.claim(1), 10_000);
        vm.prank(BOB);
        uint256 received = pots.claim(1);
        assertGt(received, 0);
        assertEq(USDC.balanceOf(BOB) - before, 10_000 + received);
        vm.prank(blacklister);
        control.unBlacklist(ALICE);
        vm.prank(ALICE);
        assertEq(upDown.claim(1), upClaim);
        vm.prank(ALICE);
        assertEq(pots.claim(1), potClaim);
    }
}

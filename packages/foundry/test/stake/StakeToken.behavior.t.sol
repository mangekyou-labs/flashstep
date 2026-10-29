// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";
import { QuirkyStakeToken } from "./QuirkyStakeToken.sol";

contract StakeTokenBehaviorTest is Test {
    QuirkyStakeToken token;
    MockBasePool pool;
    BasePoolReader reader;
    UpDownRounds up;
    ThresholdPots pot;
    address alice = address(0xa11ce);
    address bob = address(0xb0b);

    function setUp() public {
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quote = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        _deploy(6);
    }

    function _deploy(uint8 decimals) internal {
        token = new QuirkyStakeToken(decimals);
        up = new UpDownRounds(address(this), reader, address(token), 10_000);
        pot = new ThresholdPots(address(this), reader, address(token));
        token.mint(address(this), 1e26);
        token.approve(address(up), type(uint256).max);
        token.approve(address(pot), type(uint256).max);
        for (uint256 i; i < 2; ++i) {
            address who = i == 0 ? alice : bob;
            token.mint(who, 1e26);
            vm.startPrank(who);
            token.approve(address(up), type(uint256).max);
            token.approve(address(pot), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _seed() internal {
        up.fund(1_000_000);
        up.seedRound(100_000, 1 ether, 10, 4);
        pot.seedRound(
            ThresholdPots.CampaignSettings(
                0,
                1e30,
                1e36 - 1,
                10,
                4,
                type(uint64).max,
                ThresholdPots.Metric.Price,
                reader,
                MarketCapReader(address(0))
            )
        );
    }

    function _stake(address who, ThresholdPots.Side side, uint256 amount) internal {
        vm.prank(who);
        pot.stake(1, side, amount);
    }

    function _finish() internal {
        vm.warp(114);
        vm.roll(57);
        pot.captureBoundary(1);
        vm.warp(116);
        vm.roll(58);
        pot.settle(1);
    }

    function testWrongAssetAndMissingAllowanceRevertAtomically() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(StakeAsset.IncorrectPayment.selector);
        up.fund{ value: 1 }(1);
        vm.expectRevert(StakeAsset.IncorrectPayment.selector);
        pot.fund{ value: 1 }(1);
        token.approve(address(up), 0);
        token.approve(address(pot), 0);
        vm.expectRevert();
        up.fund(100);
        vm.expectRevert();
        pot.fund(100);
        assertEq(up.fundingBalance(), 0);
        assertEq(pot.fundingBalance(), 0);
        token.approve(address(up), type(uint256).max);
        _seed();
        vm.deal(alice, 1 ether);
        uint256 cost = up.quote(1, UpDownRounds.Side.Up, 1 ether);
        vm.prank(alice);
        vm.expectRevert(StakeAsset.IncorrectPayment.selector);
        up.buy{ value: cost }(1, UpDownRounds.Side.Up, 1 ether, cost);
        vm.prank(alice);
        vm.expectRevert(StakeAsset.IncorrectPayment.selector);
        pot.stake{ value: 1 }(1, ThresholdPots.Side.Yes, 1);
        vm.startPrank(alice);
        token.approve(address(up), 0);
        token.approve(address(pot), 0);
        vm.expectRevert();
        up.buy(1, UpDownRounds.Side.Up, 1 ether, cost);
        vm.expectRevert();
        pot.stake(1, ThresholdPots.Side.Yes, 100);
        vm.stopPrank();
        assertEq(pot.positionOf(1, alice).paid, 0);
    }

    function testFeeAndTransferTimeBalanceChangesRejected() public {
        token.setFee(1);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        up.fund(100);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        pot.fund(100);
        token.setFee(0);
        token.setBonus(true);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        up.fund(100);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        pot.fund(100);
        token.setBonus(false);
        _seed();
        token.setFee(1);
        uint256 cost = up.quote(1, UpDownRounds.Side.Up, 1 ether);
        vm.prank(alice);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        up.buy(1, UpDownRounds.Side.Up, 1 ether, cost);
        vm.prank(alice);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        pot.stake(1, ThresholdPots.Side.Yes, 100);
        assertEq(pot.positionOf(1, alice).paid, 0);
    }

    function testNoReturnTokenFundingTradingAndClaims() public {
        token.setNoReturn(true);
        _seed();
        uint256 cost = up.quote(1, UpDownRounds.Side.Up, 1 ether);
        vm.prank(alice);
        up.buy(1, UpDownRounds.Side.Up, 1 ether, cost);
        vm.prank(alice);
        up.sell(1, UpDownRounds.Side.Up, 1 ether, 0);
        _stake(alice, ThresholdPots.Side.Yes, 200);
        _stake(bob, ThresholdPots.Side.No, 200);
        _finish();
        vm.prank(alice);
        assertEq(pot.claim(1), 400);
        up.withdrawLiquidity(100);
    }

    function testBlockedWinnerDoesNotBlockAnotherClaimAndCanRetry() public {
        _seed();
        _stake(alice, ThresholdPots.Side.Yes, 100);
        _stake(bob, ThresholdPots.Side.Yes, 100);
        _stake(address(this), ThresholdPots.Side.No, 200);
        _finish();
        token.setBlocked(alice, true);
        vm.prank(alice);
        vm.expectRevert();
        pot.claim(1);
        assertEq(pot.claimable(1, alice), 200);
        vm.prank(bob);
        assertEq(pot.claim(1), 200);
        token.setBlocked(alice, false);
        vm.prank(alice);
        assertEq(pot.claim(1), 200);
        assertEq(pot.reservedBalance(), 0);
    }

    function testPausedAndFeeOutgoingClaimsRollbackThenRetry() public {
        _seed();
        _stake(alice, ThresholdPots.Side.Yes, 100);
        _stake(bob, ThresholdPots.Side.No, 100);
        _finish();
        token.setPaused(true);
        vm.prank(alice);
        vm.expectRevert();
        pot.claim(1);
        token.setPaused(false);
        token.setFee(1);
        vm.prank(alice);
        vm.expectRevert(StakeAsset.UnsupportedTransfer.selector);
        pot.claim(1);
        assertEq(pot.claimable(1, alice), 200);
        assertEq(pot.reservedBalance(), 200);
        token.setFee(0);
        vm.prank(alice);
        assertEq(pot.claim(1), 200);
    }

    function testTokenCallbacksCannotReenterStakeOrClaim() public {
        _seed();
        token.setCallback(address(pot), abi.encodeCall(pot.stake, (1, ThresholdPots.Side.Yes, 1)));
        _stake(alice, ThresholdPots.Side.Yes, 100);
        assertFalse(token.callbackSucceeded());
        _stake(bob, ThresholdPots.Side.No, 100);
        _finish();
        token.setCallback(address(pot), abi.encodeCall(pot.claim, (1)));
        vm.prank(alice);
        assertEq(pot.claim(1), 200);
        assertFalse(token.callbackSucceeded());
        assertEq(pot.reservedBalance(), 0);
    }

    function testFuzzSixDecimalUpDownPayouts(uint64 rawPayout, uint32 rawShares) public {
        _fuzzUpDown(6, rawPayout, rawShares);
    }

    function testFuzzEighteenDecimalUpDownPayouts(uint64 rawPayout, uint32 rawShares) public {
        _fuzzUpDown(18, rawPayout, rawShares);
    }

    function _fuzzUpDown(uint8 decimals, uint64 rawPayout, uint32 rawShares) internal {
        _deploy(decimals);
        uint256 payout = bound(uint256(rawPayout), 1, 10 ** decimals);
        uint256 shareCount = bound(uint256(rawShares), 1, 90);
        up = new UpDownRounds(address(this), reader, address(token), payout);
        token.approve(address(up), type(uint256).max);
        vm.prank(alice);
        token.approve(address(up), type(uint256).max);
        up.fund(payout * 1000);
        up.seedRound(payout * 100, 1e30, 10, 4);
        uint256 cost = up.quote(1, UpDownRounds.Side.Up, shareCount * 1 ether);
        uint256 beforeAlice = token.balanceOf(alice);
        vm.prank(alice);
        up.buy(1, UpDownRounds.Side.Up, shareCount * 1 ether, cost);
        vm.warp(110);
        vm.roll(15);
        up.captureBoundary(1);
        pool.write(1);
        vm.warp(114);
        vm.roll(17);
        up.captureBoundary(1);
        vm.warp(130);
        vm.roll(25);
        up.settle(1);
        vm.prank(alice);
        assertEq(up.claim(1), shareCount * payout);
        assertEq(token.balanceOf(alice), beforeAlice - cost + shareCount * payout);
    }

    function testFuzzSixDecimalPayouts(uint96 amount) public {
        _fuzzRawPayout(6, amount);
    }

    function testFuzzEighteenDecimalPayouts(uint96 amount) public {
        _fuzzRawPayout(18, amount);
    }

    function _fuzzRawPayout(uint8 decimals, uint96 raw) internal {
        _deploy(decimals);
        _seed();
        uint256 amount = bound(uint256(raw), 1, 1000 * 10 ** decimals);
        uint256 beforeAlice = token.balanceOf(alice);
        _stake(alice, ThresholdPots.Side.Yes, amount);
        _stake(bob, ThresholdPots.Side.No, amount);
        _finish();
        vm.prank(alice);
        assertEq(pot.claim(1), 2 * amount);
        assertEq(token.balanceOf(alice), beforeAlice + amount);
        assertEq(token.balanceOf(address(pot)), 0);
    }
}

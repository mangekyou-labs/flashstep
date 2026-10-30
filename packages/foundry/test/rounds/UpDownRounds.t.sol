// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract UpDownRoundsTest is RoundFixture {
    function testPhaseMovesWithoutTransactions() public {
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Trading));
        vm.warp(110);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Window));
        vm.warp(114);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.AwaitingSettlement));
    }

    function testWinningClaimAndLosingAndRepeatedClaims() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 1e18);
        buyAs(bob, UpDownRounds.Side.Down, 1e18);
        assertEq(_balance(alice), 100 ether - paid);
        finish(100);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Settled));
        UpDownRounds.Round memory r = market.round(1);
        assertLt(r.startReading.price, r.endReading.price);
        assertEq(r.startReading.price, 1e36);
        assertEq(market.claimable(1, alice), 0.01 ether);
        assertEq(market.claimable(1, bob), 0);
        uint256 beforeBalance = _balance(alice);
        vm.prank(alice);
        market.claim(1);
        assertEq(_balance(alice) - beforeBalance, 0.01 ether);
        assertEq(market.claimable(1, alice), 0);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
        vm.prank(bob);
        assertEq(market.claim(1), 0);
    }

    function testDownWinsAndClaimsNeverExpire() public {
        buyAs(alice, UpDownRounds.Side.Down, 2e18);
        finish(-100);
        vm.warp(100000000);
        vm.prank(alice);
        assertEq(market.claim(1), 0.02 ether);
    }

    function testTieRefundsExactlyTheBuyCost() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 1e18);
        finish(0);
        uint256 balance = _balance(alice);
        vm.prank(alice);
        market.claim(1);
        assertEq(_balance(alice) - balance, paid);
    }

    function testBuyAtCutoffAndAfterWindowReverts() public {
        vm.warp(110);
        vm.expectRevert(UpDownRounds.OutsideTrading.selector);
        vm.prank(alice);
        market.buy(1, UpDownRounds.Side.Up, 1e18, 1 ether);
        vm.warp(114);
        vm.expectRevert(UpDownRounds.OutsideTrading.selector);
        vm.prank(alice);
        market.buy(1, UpDownRounds.Side.Up, 1e18, 1 ether);
    }

    function testSlippageAndPaymentMismatchDoNotChangePosition() public {
        uint256 oldQuote = market.quote(1, UpDownRounds.Side.Up, 1e18);
        buyAs(bob, UpDownRounds.Side.Up, 5e18);
        vm.expectRevert(UpDownRounds.SlippageExceeded.selector);
        vm.prank(alice);
        market.buy{ value: _value(oldQuote) }(1, UpDownRounds.Side.Up, 1e18, oldQuote);
        uint256 freshQuote = market.quote(1, UpDownRounds.Side.Up, 1e18);
        if (address(stakeToken) != address(0)) vm.deal(alice, freshQuote + 1);
        vm.expectRevert(StakeAsset.IncorrectPayment.selector);
        vm.prank(alice);
        market.buy{ value: freshQuote + 1 }(1, UpDownRounds.Side.Up, 1e18, freshQuote);
        assertEq(market.positionOf(1, alice).paid, 0);
    }

    function testSettleEarlyAndMissingBoundaryRevert() public {
        vm.warp(113);
        vm.expectRevert(UpDownRounds.TooEarlyToSettle.selector);
        market.settle(1);
        vm.warp(114);
        vm.expectRevert(UpDownRounds.NoValidReading.selector);
        market.settle(1);
        vm.warp(115);
        vm.expectRevert(UpDownRounds.OutsideBoundary.selector);
        market.captureBoundary(1);
    }

    function testBoundaryCannotBeReplacedByLatePrice() public {
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        finish(100);
        pool.write(-10000);
        vm.warp(140);
        vm.roll(30);
        assertEq(market.claimable(1, alice), 0.01 ether);
        vm.expectRevert(UpDownRounds.AlreadySettled.selector);
        market.settle(1);
    }

    function testFundingAndSeedingAreOwnerOnly() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vm.prank(alice);
        market.fund{ value: _value(1 ether) }(1 ether);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", alice));
        vm.prank(alice);
        market.seedRound(1 ether, 1 ether, 10, 4);
        vm.expectRevert(UpDownRounds.RoundAlreadySeeded.selector);
        market.seedRound(1 ether, 1 ether, 10, 4);
        vm.expectRevert(UpDownRounds.PayerCannotBuy.selector);
        market.buy(1, UpDownRounds.Side.Up, 1, 1);
    }

    function testUnknownRoundAndZeroSharesRevert() public {
        vm.expectRevert(UpDownRounds.UnknownRound.selector);
        market.phase(0);
        vm.expectRevert(UpDownRounds.InvalidAmount.selector);
        market.quote(1, UpDownRounds.Side.Up, 0);
        vm.expectRevert(UpDownRounds.InsufficientReserve.selector);
        market.quote(1, UpDownRounds.Side.Up, 91e18);
    }

    function testRoundPageViewsQuoteChanceAndPayoutOnchain() public {
        assertEq(market.chanceCents(1), 50);
        buyAs(alice, UpDownRounds.Side.Up, 20e18);
        assertEq(market.chanceCents(1), 75);
        assertEq(market.payoutFor(3e18), 0.03 ether);
        vm.warp(104);
        assertEq(reader.preview().price, 1e36);
        assertEq(reader.preview().timestamp, block.timestamp);
    }

    function testKnownSpeedrunAverageChanceQuote() public view {
        // 10 opening shares each; buying 20 Up moves chance from 1/2 to 3/4.
        // Average chance 5/8, 20 shares at .01 ETH payout => .125 ETH.
        assertEq(market.quote(1, UpDownRounds.Side.Up, 20e18), 0.125 ether);
    }

    function testCaptureAfterSettlementCannotChangeEndpoints() public {
        finish(100);
        vm.warp(114);
        vm.roll(99);
        vm.expectRevert(UpDownRounds.AlreadySettled.selector);
        market.captureBoundary(1);
    }

    function testRepeatedBoundaryCaptureKeepsFirstBlock() public {
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        vm.roll(16);
        market.captureBoundary(1);
        pool.write(100);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        market.settle(1);
        assertEq(market.round(1).startReading.blockNumber, 15);
    }

    function testPositionPredictsActualPayoutAndSpentETH() public {
        uint256 beforeBalance = _balance(alice);
        buyAs(alice, UpDownRounds.Side.Up, 3e18);
        buyAs(alice, UpDownRounds.Side.Down, 2e18);
        UpDownRounds.Position memory position = market.positionOf(1, alice);
        assertEq(position.paid, beforeBalance - _balance(alice));
        finish(100);
        uint256 predicted = position.up * 0.01 ether / 1e18;
        assertEq(market.claimable(1, alice), predicted);
        beforeBalance = _balance(alice);
        vm.prank(alice);
        market.claim(1);
        assertEq(_balance(alice) - beforeBalance, predicted);
    }
}

contract UpDownRoundsTestERC20 is UpDownRoundsTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

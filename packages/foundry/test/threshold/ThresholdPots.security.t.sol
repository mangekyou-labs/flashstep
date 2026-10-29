// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ThresholdReceiver {
    ThresholdPots public market;
    bool public reject;
    bool public callbackSeen;
    bool public claimReentryBlocked;
    bool public settleReentryBlocked;
    bool public fundingReentryBlocked;
    bool public dustReentryBlocked;
    uint256 public claimableDuringPayment;
    uint256 public fundingDuringPayment;
    uint256 public dustDuringPayment;

    constructor(ThresholdPots market_) {
        market = market_;
    }

    function setReject(bool value) external {
        reject = value;
    }

    function setMarket(ThresholdPots value) external {
        market = value;
    }

    function stake(uint256 roundId, ThresholdPots.Side side) external payable {
        market.stake{ value: msg.value }(roundId, side);
    }

    function claim() external {
        market.claim(1);
    }

    function withdrawFunding(uint256 amount) external {
        market.withdrawFunding(amount);
    }

    function withdrawDust() external {
        market.withdrawDust();
    }

    receive() external payable {
        if (reject) revert("recipient refuses ETH");
        callbackSeen = true;
        claimableDuringPayment = market.claimable(1, address(this));
        fundingDuringPayment = market.fundingBalance();
        dustDuringPayment = market.dustCredit(address(this));
        (bool success, bytes memory reason) = address(market).call(abi.encodeCall(market.claim, (1)));
        claimReentryBlocked = !success && bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        (success, reason) = address(market).call(abi.encodeCall(market.settle, (1)));
        settleReentryBlocked = !success && bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        (success, reason) = address(market).call(abi.encodeCall(market.withdrawFunding, (1)));
        fundingReentryBlocked = !success && bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        (success, reason) = address(market).call(abi.encodeCall(market.withdrawDust, ()));
        dustReentryBlocked = !success && bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
    }
}

contract ThresholdPotsSecurityTest is Test {
    ThresholdPots market;
    BasePoolReader reader;
    MockBasePool pool;
    address alice = address(0xA11CE);

    function setUp() public {
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quote = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        market = new ThresholdPots(address(this), reader);
        vm.deal(address(this), 100 ether);
        vm.deal(alice, 10 ether);
        market.fund{ value: 10 ether }();
        market.seedRound(
            ThresholdPots.CampaignSettings({
                openingStake: 1,
                stakeCap: 1 ether,
                threshold: 1e36 - 1,
                tradingSeconds: 10,
                windowSeconds: 4,
                endTime: 200,
                metric: ThresholdPots.Metric.Price,
                reader: reader,
                marketCapReader: MarketCapReader(address(0))
            })
        );
    }

    function finish() internal {
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        vm.warp(116);
        vm.roll(18);
        market.settle(1);
    }

    function testClaimCallbackSeesConsumedPositionAndBlocksReentry() public {
        ThresholdReceiver receiver = new ThresholdReceiver(market);
        receiver.stake{ value: 1 }(1, ThresholdPots.Side.Yes);
        finish();
        receiver.claim();
        assertEq(address(receiver).balance, 1);
        assertTrue(receiver.callbackSeen());
        assertEq(receiver.claimableDuringPayment(), 0);
        assertTrue(receiver.claimReentryBlocked());
        assertTrue(receiver.settleReentryBlocked());
        assertTrue(receiver.dustReentryBlocked());
        assertEq(market.claimable(1, address(receiver)), 0);
        receiver.claim();
        assertEq(address(receiver).balance, 1);
    }

    function testRejectingWinnerRollsBackOnlyTheirClaim() public {
        ThresholdReceiver receiver = new ThresholdReceiver(market);
        receiver.stake{ value: 1 }(1, ThresholdPots.Side.Yes);
        finish();
        receiver.setReject(true);
        vm.expectRevert(ThresholdPots.TransferFailed.selector);
        receiver.claim();
        assertEq(market.claimable(1, address(receiver)), 1);
        assertFalse(market.positionOf(1, address(receiver)).claimed);
        assertEq(address(market).balance, 10 ether + 1);
        uint256 before = address(this).balance;
        market.claim(1);
        assertEq(address(this).balance - before, 1);
        assertEq(market.claimable(1, address(receiver)), 1);
        receiver.setReject(false);
        receiver.claim();
        assertEq(address(receiver).balance, 1);
        assertEq(market.dustCredit(address(this)), 1);
    }

    function testFundingWithdrawalRollsBackOnRejectionThenChecksEffectsBeforeCallback() public {
        ThresholdReceiver receiver = new ThresholdReceiver(market);
        market.transferOwnership(address(receiver));
        uint256 funding = market.fundingBalance();
        uint256 held = address(market).balance;
        receiver.setReject(true);
        vm.expectRevert(ThresholdPots.TransferFailed.selector);
        receiver.withdrawFunding(3);
        assertEq(market.fundingBalance(), funding);
        assertEq(address(market).balance, held);
        receiver.setReject(false);
        receiver.withdrawFunding(3);
        assertEq(receiver.fundingDuringPayment(), funding - 3);
        assertEq(address(receiver).balance, 3);
        assertTrue(receiver.claimReentryBlocked());
        assertTrue(receiver.settleReentryBlocked());
        assertTrue(receiver.fundingReentryBlocked());
        assertTrue(receiver.dustReentryBlocked());
        assertEq(market.round(1).collateral, 2);
    }

    function testOwnershipCannotRedirectOpeningStakesOrDustAndDustWithdrawalIsAtomic() public {
        ThresholdReceiver payer = new ThresholdReceiver(market);
        market = new ThresholdPots(address(payer), reader);
        payer.setMarket(market);
        vm.deal(address(payer), 10);
        vm.prank(address(payer));
        market.fund{ value: 2 }();
        vm.prank(address(payer));
        market.seedRound(
            ThresholdPots.CampaignSettings({
                openingStake: 1,
                stakeCap: 1 ether,
                threshold: 1e36 - 1,
                tradingSeconds: 10,
                windowSeconds: 4,
                endTime: 200,
                metric: ThresholdPots.Metric.Price,
                reader: reader,
                marketCapReader: MarketCapReader(address(0))
            })
        );
        vm.prank(alice);
        market.stake{ value: 1 }(1, ThresholdPots.Side.Yes);
        vm.prank(address(payer));
        market.transferOwnership(alice);
        finish();
        assertEq(market.round(1).payer, address(payer));
        assertEq(market.positionOf(1, address(payer)).yes, 1);
        assertEq(market.positionOf(1, address(payer)).no, 1);
        assertEq(market.claimable(1, address(payer)), 1);
        assertEq(market.claimable(1, alice), 1);
        payer.claim();
        vm.prank(alice);
        market.claim(1);
        assertEq(market.dustCredit(address(payer)), 1);
        assertEq(market.dustCredit(alice), 0);
        vm.prank(alice);
        assertEq(market.withdrawDust(), 0);
        payer.setReject(true);
        vm.expectRevert(ThresholdPots.TransferFailed.selector);
        payer.withdrawDust();
        assertEq(market.dustCredit(address(payer)), 1);
        assertEq(market.totalDustCredit(), 1);
        assertEq(address(market).balance, 1);
        payer.setReject(false);
        payer.withdrawDust();
        assertEq(payer.dustDuringPayment(), 0);
        assertTrue(payer.claimReentryBlocked());
        assertTrue(payer.settleReentryBlocked());
        assertTrue(payer.dustReentryBlocked());
        assertEq(market.totalDustCredit(), 0);
        assertEq(address(market).balance, 0);
    }

    receive() external payable { }
}

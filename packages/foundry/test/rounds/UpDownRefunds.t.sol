// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ClaimReceiver } from "./UpDownRounds.security.t.sol";
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";

contract RefundPayer {
    UpDownRounds public market;
    bool public reject;
    bool public reentryBlocked;
    uint256 public creditDuringPayment;

    constructor(BasePoolReader reader) payable {
        market = new UpDownRounds(address(this), reader);
        market.fund{ value: msg.value }();
        market.seedRound(msg.value, msg.value, 10, 4);
    }

    function setReject(bool value) external {
        reject = value;
    }

    function withdraw() external {
        market.withdrawRefund();
    }

    receive() external payable {
        if (reject) revert();
        creditDuringPayment = market.refundCredit(address(this));
        try market.withdrawRefund() { }
        catch (bytes memory reason) {
            reentryBlocked = bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        }
    }
}

contract UpDownRefundsTest is RoundFixture {
    function _captureBoth() private {
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        pool.write(100);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
    }

    function testMissingEndObservationRefundsStakeAfterDeadline() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 20e18);
        vm.warp(110);
        vm.roll(15);
        market.captureBoundary(1);
        pool.setMissingAtBlock(17, true);
        vm.warp(114);
        vm.roll(17);
        vm.expectRevert(BasePoolReader.NoValidReading.selector);
        market.captureBoundary(1);
        vm.warp(174);
        vm.roll(47);
        market.settle(1);
        uint256 beforeBalance = alice.balance;
        vm.prank(alice);
        assertEq(market.claim(1), paid);
        assertEq(alice.balance - beforeBalance, paid);
    }

    function testMissingReadingDeadlineOneSecondBeforeExactlyAndAfter() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Down, 20e18);
        vm.warp(173);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.AwaitingSettlement));
        assertEq(market.claimable(1, alice), 0);
        vm.expectRevert(UpDownRounds.NoValidReading.selector);
        market.settle(1);
        vm.prank(alice);
        vm.expectRevert(UpDownRounds.NotSettled.selector);
        market.claim(1);
        vm.warp(174);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Refunded));
        assertEq(market.claimable(1, alice), paid);
        vm.warp(175);
        assertEq(market.claimable(1, alice), paid);
        vm.prank(alice);
        assertEq(market.claim(1), paid);
    }

    function testUnsettledExpiryOneSecondBeforeExactlyAndAfterWithValidReadings() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Down, 20e18);
        _captureBoth();
        vm.warp(114 + 24 hours - 1);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.AwaitingSettlement));
        assertEq(market.claimable(1, alice), 0);
        vm.prank(alice);
        vm.expectRevert(UpDownRounds.NotSettled.selector);
        market.claim(1);
        vm.warp(114 + 24 hours);
        assertEq(uint256(market.phase(1)), uint256(UpDownRounds.Phase.Refunded));
        assertEq(market.claimable(1, alice), paid);
        vm.warp(114 + 24 hours + 1);
        vm.prank(alice);
        assertEq(market.claim(1), paid);
        assertEq(uint256(market.round(1).result), uint256(UpDownRounds.Result.Refunded));
    }

    function testValidCapturedReadingsStillSettleAtGraceDeadline() public {
        buyAs(alice, UpDownRounds.Side.Up, 20e18);
        _captureBoth();
        vm.warp(174);
        market.settle(1);
        assertEq(market.claimable(1, alice), 0.2 ether);
    }

    function testSettledWinningsNeverBecomeRefundsAndClaimsNeverExpire() public {
        buyAs(alice, UpDownRounds.Side.Up, 20e18);
        finish(100);
        vm.warp(114 + 3650 days);
        assertEq(market.claimable(1, alice), 0.2 ether);
        vm.prank(alice);
        assertEq(market.claim(1), 0.2 ether);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
    }

    function testRefundPaysNetStakeOnceAndOriginalPayerKeepsEntireSeed() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 20e18);
        uint256 proceeds = market.quoteSell(1, UpDownRounds.Side.Up, 10e18);
        vm.prank(alice);
        market.sell(1, UpDownRounds.Side.Up, 10e18, proceeds);
        market.transferOwnership(bob);
        vm.warp(174);
        uint256 beforeBalance = alice.balance;
        vm.prank(alice);
        assertEq(market.claim(1), paid - proceeds);
        assertEq(alice.balance - beforeBalance, paid - proceeds);
        vm.prank(alice);
        assertEq(market.claim(1), 0);
        vm.warp(174 + 3650 days);
        assertEq(market.withdrawRefund(), 1 ether);
        assertEq(market.withdrawRefund(), 0);
        vm.prank(bob);
        assertEq(market.withdrawRefund(), 0);
        assertEq(address(market).balance, 9 ether);
    }

    function testRenouncedPayerCanWithdrawSeedRefundForever() public {
        buyAs(alice, UpDownRounds.Side.Up, 20e18);
        market.withdrawLiquidity(9 ether);
        market.renounceOwnership();
        vm.warp(114 + 24 hours);
        market.settle(1);
        vm.warp(114 + 3650 days);
        assertEq(market.withdrawRefund(), 1 ether);
        vm.prank(alice);
        market.claim(1);
        assertEq(address(market).balance, 0);
    }

    function testExpirySettlementRefundsInsteadOfPayingKnownWinner() public {
        uint256 paid = buyAs(alice, UpDownRounds.Side.Up, 20e18);
        _captureBoth();
        vm.warp(114 + 24 hours);
        market.settle(1);
        assertEq(market.claimable(1, alice), paid);
    }

    function testExpiredIdleSlotsCannotConsumeSeedFunding() public {
        vm.warp(1000);
        uint256 held = address(market).balance;
        for (uint256 id = 2; id <= 20; ++id) {
            assertEq(market.claim(id), 0);
            vm.expectRevert(UpDownRounds.UnknownRound.selector);
            market.settle(id);
        }
        assertEq(market.fundingBalance(), 9 ether);
        assertEq(market.totalRefundCredit(), 0);
        assertEq(address(market).balance, held);
    }

    function testRejectedAutoRefundRollsBackAndOtherPlayersCanClaim() public {
        ClaimReceiver receiver = new ClaimReceiver(market);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        receiver.buy{ value: cost }();
        uint256 alicePaid = buyAs(alice, UpDownRounds.Side.Down, 1e18);
        vm.warp(174);
        receiver.setReject(true);
        vm.expectRevert(UpDownRounds.TransferFailed.selector);
        receiver.claim();
        assertEq(uint256(market.round(1).result), uint256(UpDownRounds.Result.None));
        assertEq(market.totalRefundCredit(), 0);
        assertEq(market.claimable(1, address(receiver)), cost);
        vm.prank(alice);
        assertEq(market.claim(1), alicePaid);
        receiver.setReject(false);
        receiver.claim();
        assertEq(address(receiver).balance, cost);
        assertTrue(receiver.reentryBlocked());
        assertTrue(receiver.settleBlocked());
        assertEq(receiver.claimableDuringPayment(), 0);
    }

    function testPayerRefundRejectRollsBackAndPaymentClearsCreditBeforeReentry() public {
        RefundPayer payer = new RefundPayer{ value: 1 ether }(reader);
        UpDownRounds other = payer.market();
        vm.warp(174);
        other.settle(1);
        payer.setReject(true);
        vm.expectRevert(UpDownRounds.TransferFailed.selector);
        payer.withdraw();
        assertEq(other.refundCredit(address(payer)), 1 ether);
        assertEq(other.totalRefundCredit(), 1 ether);
        payer.setReject(false);
        payer.withdraw();
        assertEq(address(payer).balance, 1 ether);
        assertTrue(payer.reentryBlocked());
        assertEq(payer.creditDuringPayment(), 0);
        assertEq(other.totalRefundCredit(), 0);
        assertEq(address(other).balance, 0);
        payer.withdraw();
        assertEq(address(payer).balance, 1 ether);
    }

    receive() external payable { }
}

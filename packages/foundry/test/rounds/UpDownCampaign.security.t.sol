// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract CampaignReceiver {
    UpDownRounds market;
    bool public reject;
    bool public reentryBlocked;
    uint256 public sharesDuringPayment;
    uint256 public fundingDuringPayment;

    constructor(UpDownRounds market_) {
        market = market_;
    }

    function setReject(bool value) external {
        reject = value;
    }

    function buy() external payable {
        market.buy{ value: msg.value }(1, UpDownRounds.Side.Up, 1e18, msg.value);
    }

    function sell() external {
        market.sell(1, UpDownRounds.Side.Up, 1e18, 1);
    }

    function withdraw(uint256 amount) external {
        market.withdrawLiquidity(amount);
    }

    receive() external payable {
        if (reject) revert();
        sharesDuringPayment = market.positionOf(1, address(this)).up;
        fundingDuringPayment = market.fundingBalance();
        try market.sell(1, UpDownRounds.Side.Up, 1, 0) { }
        catch (bytes memory reason) {
            reentryBlocked = bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        }
    }
}

contract UpDownCampaignSecurityTest is RoundFixture {
    function testSellRejectingRecipientRollsBackAndCallbackSeesConsumedShares() public {
        CampaignReceiver receiver = new CampaignReceiver(market);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        receiver.buy{ value: cost }();
        uint256 custody = address(market).balance;
        receiver.setReject(true);
        vm.expectRevert(UpDownRounds.TransferFailed.selector);
        receiver.sell();
        assertEq(market.positionOf(1, address(receiver)).up, 1e18);
        assertEq(market.positionOf(1, address(receiver)).proceeds, 0);
        assertEq(address(market).balance, custody);
        receiver.setReject(false);
        uint256 expected = market.quoteSell(1, UpDownRounds.Side.Up, 1e18);
        receiver.sell();
        assertEq(address(receiver).balance, expected);
        assertEq(receiver.sharesDuringPayment(), 0);
        assertTrue(receiver.reentryBlocked());
    }

    function testWithdrawalRejectingOwnerRollsBackAndCallbackSeesReducedFunding() public {
        CampaignReceiver receiver = new CampaignReceiver(market);
        market.transferOwnership(address(receiver));
        receiver.setReject(true);
        vm.expectRevert(UpDownRounds.TransferFailed.selector);
        receiver.withdraw(1 ether);
        assertEq(market.fundingBalance(), 9 ether);
        assertEq(address(market).balance, 10 ether);
        receiver.setReject(false);
        receiver.withdraw(1 ether);
        assertEq(receiver.fundingDuringPayment(), 8 ether);
        assertEq(address(receiver).balance, 1 ether);
        assertTrue(receiver.reentryBlocked());
        assertEq(market.reservedBalance(), 1 ether);
    }
}

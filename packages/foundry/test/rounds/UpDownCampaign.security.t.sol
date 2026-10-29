// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract CampaignReceiver is StakeTestBase {
    UpDownRounds market;
    bool public reject;
    bool public reentryBlocked;
    uint256 public sharesDuringPayment;
    uint256 public fundingDuringPayment;

    constructor(UpDownRounds market_) {
        market = market_;
        _setStakeToken(market_.i_stakeToken());
        if (address(stakeToken) != address(0)) {
            stakeToken.setCallback(address(this));
            _approve(address(this), address(market_));
        }
    }

    function setReject(bool value) external {
        reject = value;
    }

    function buy(uint256 amount) external payable {
        market.buy{ value: _value(amount) }(1, UpDownRounds.Side.Up, 1e18, amount);
    }

    function sell() external {
        market.sell(1, UpDownRounds.Side.Up, 1e18, 1);
    }

    function withdraw(uint256 amount) external {
        market.withdrawLiquidity(amount);
    }

    receive() external payable {
        onStakeReceived();
    }

    function onStakeReceived() public {
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
        if (address(stakeToken) != address(0)) stakeToken.transfer(address(receiver), cost);
        receiver.buy{ value: _value(cost) }(cost);
        uint256 custody = _balance(address(market));
        receiver.setReject(true);
        if (address(stakeToken) == address(0)) vm.expectRevert(StakeAsset.TransferFailed.selector);
        else vm.expectRevert();
        receiver.sell();
        assertEq(market.positionOf(1, address(receiver)).up, 1e18);
        assertEq(market.positionOf(1, address(receiver)).proceeds, 0);
        assertEq(_balance(address(market)), custody);
        receiver.setReject(false);
        uint256 expected = market.quoteSell(1, UpDownRounds.Side.Up, 1e18);
        receiver.sell();
        assertEq(_balance(address(receiver)), expected);
        assertEq(receiver.sharesDuringPayment(), 0);
        assertTrue(receiver.reentryBlocked());
    }

    function testWithdrawalRejectingOwnerRollsBackAndCallbackSeesReducedFunding() public {
        CampaignReceiver receiver = new CampaignReceiver(market);
        market.transferOwnership(address(receiver));
        receiver.setReject(true);
        if (address(stakeToken) == address(0)) vm.expectRevert(StakeAsset.TransferFailed.selector);
        else vm.expectRevert();
        receiver.withdraw(1 ether);
        assertEq(market.fundingBalance(), 9 ether);
        assertEq(_balance(address(market)), 10 ether);
        receiver.setReject(false);
        receiver.withdraw(1 ether);
        assertEq(receiver.fundingDuringPayment(), 8 ether);
        assertEq(_balance(address(receiver)), 1 ether);
        assertTrue(receiver.reentryBlocked());
        assertEq(market.reservedBalance(), 1 ether);
    }
}

contract UpDownCampaignSecurityTestERC20 is UpDownCampaignSecurityTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

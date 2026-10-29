// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract ClaimReceiver is StakeTestBase {
    UpDownRounds market;
    bool public reject;
    bool public reentryBlocked;
    bool public settleBlocked;
    uint256 public claimableDuringPayment;

    constructor(UpDownRounds m) {
        market = m;
        _setStakeToken(m.i_stakeToken());
        if (address(stakeToken) != address(0)) {
            stakeToken.setCallback(address(this));
            _approve(address(this), address(m));
        }
    }

    function buy(uint256 amount) external payable {
        market.buy{ value: _value(amount) }(1, UpDownRounds.Side.Up, 1e18, amount);
    }

    function setReject(bool value) external {
        reject = value;
    }

    function claim() external {
        market.claim(1);
    }

    receive() external payable {
        onStakeReceived();
    }

    function onStakeReceived() public {
        if (reject) revert();
        claimableDuringPayment = market.claimable(1, address(this));
        try market.claim(1) { }
        catch (bytes memory reason) {
            reentryBlocked = bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        }
        try market.settle(1) { }
        catch (bytes memory reason) {
            settleBlocked = bytes4(reason) == bytes4(keccak256("ReentrancyGuardReentrantCall()"));
        }
    }
}

contract UpDownRoundsSecurityTest is RoundFixture {
    function testClaimUpdatesStateBeforeCallbackAndBlocksReentry() public {
        ClaimReceiver receiver = new ClaimReceiver(market);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        if (address(stakeToken) != address(0)) stakeToken.transfer(address(receiver), cost);
        receiver.buy{ value: _value(cost) }(cost);
        finish(100);
        receiver.claim();
        assertEq(_balance(address(receiver)), 0.01 ether);
        assertTrue(receiver.reentryBlocked());
        assertTrue(receiver.settleBlocked());
        assertEq(receiver.claimableDuringPayment(), 0);
    }

    function testRejectingRecipientKeepsItsClaimAndDoesNotBlockOthers() public {
        ClaimReceiver receiver = new ClaimReceiver(market);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        if (address(stakeToken) != address(0)) stakeToken.transfer(address(receiver), cost);
        receiver.buy{ value: _value(cost) }(cost);
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        finish(100);
        receiver.setReject(true);
        if (address(stakeToken) == address(0)) vm.expectRevert(StakeAsset.TransferFailed.selector);
        else vm.expectRevert();
        receiver.claim();
        assertEq(market.claimable(1, address(receiver)), 0.01 ether);
        vm.prank(alice);
        market.claim(1);
        receiver.setReject(false);
        receiver.claim();
        assertEq(_balance(address(receiver)), 0.01 ether);
    }
}

contract UpDownRoundsSecurityTestERC20 is UpDownRoundsSecurityTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

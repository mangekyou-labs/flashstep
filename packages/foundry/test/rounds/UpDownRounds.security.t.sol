// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { RoundFixture } from "./RoundFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";

contract ClaimReceiver {
    UpDownRounds market;
    bool public reject;
    bool public reentryBlocked;
    bool public settleBlocked;
    uint256 public claimableDuringPayment;

    constructor(UpDownRounds m) {
        market = m;
    }

    function buy() external payable {
        market.buy{ value: msg.value }(1, UpDownRounds.Side.Up, 1e18, msg.value);
    }

    function setReject(bool value) external {
        reject = value;
    }

    function claim() external {
        market.claim(1);
    }

    receive() external payable {
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
        receiver.buy{ value: cost }();
        finish(100);
        receiver.claim();
        assertEq(address(receiver).balance, 0.01 ether);
        assertTrue(receiver.reentryBlocked());
        assertTrue(receiver.settleBlocked());
        assertEq(receiver.claimableDuringPayment(), 0);
    }

    function testRejectingRecipientKeepsItsClaimAndDoesNotBlockOthers() public {
        ClaimReceiver receiver = new ClaimReceiver(market);
        uint256 cost = market.quote(1, UpDownRounds.Side.Up, 1e18);
        receiver.buy{ value: cost }();
        buyAs(alice, UpDownRounds.Side.Up, 1e18);
        finish(100);
        receiver.setReject(true);
        vm.expectRevert(UpDownRounds.TransferFailed.selector);
        receiver.claim();
        assertEq(market.claimable(1, address(receiver)), 0.01 ether);
        vm.prank(alice);
        market.claim(1);
        receiver.setReject(false);
        receiver.claim();
        assertEq(address(receiver).balance, 0.01 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { PayerDeployFixture } from "./PayerDeployFixture.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";

contract PayerOwnershipTest is PayerDeployFixture {
    function _deployed() internal view returns (address upDown, address threshold) {
        string memory json = vm.readFile(OUT_PATH);
        upDown = vm.parseJsonAddress(json, ".upDown");
        threshold = vm.parseJsonAddress(json, ".threshold");
    }

    function test_payerOwnsBothContractsAndNobodyElseHoldsARole() public {
        script.run();
        (address upDown, address threshold) = _deployed();

        assertEq(UpDownRounds(upDown).owner(), payer, "UpDownRounds owner");
        assertEq(ThresholdPots(threshold).owner(), payer, "ThresholdPots owner");

        // The developer (this test), the script contract and the default sender hold nothing.
        address[3] memory others = [address(this), address(script), DEFAULT_SENDER];
        for (uint256 i; i < others.length; ++i) {
            assertTrue(UpDownRounds(upDown).owner() != others[i]);
            assertTrue(ThresholdPots(threshold).owner() != others[i]);
        }
        // Single-step Ownable, no second role: there is no pending owner or any other privileged getter.
        (bool hasPending,) = upDown.staticcall(abi.encodeWithSignature("pendingOwner()"));
        assertFalse(hasPending, "UpDownRounds pendingOwner");
        (hasPending,) = threshold.staticcall(abi.encodeWithSignature("pendingOwner()"));
        assertFalse(hasPending, "ThresholdPots pendingOwner");
    }
}

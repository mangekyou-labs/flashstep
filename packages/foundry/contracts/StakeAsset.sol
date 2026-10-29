// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Fixed stake-asset custody. All amounts are raw token units; zero address selects ETH.
/// Fee-on-transfer and rebasing assets are unsupported. Transfers must move exactly the requested units.
abstract contract StakeAsset {
    using SafeERC20 for IERC20;

    error InvalidStakeAsset();
    error IncorrectPayment();
    error TransferFailed();
    error UnsupportedTransfer();

    address public immutable i_stakeToken;

    constructor(address stakeToken) {
        if (stakeToken != address(0) && stakeToken.code.length == 0) revert InvalidStakeAsset();
        i_stakeToken = stakeToken;
    }

    /// @dev Called only from guarded entry points, after accounting effects and before returning.
    function _takeStake(uint256 amount) internal {
        if (i_stakeToken == address(0)) {
            if (msg.value != amount) revert IncorrectPayment();
        } else {
            if (msg.value != 0) revert IncorrectPayment();
            IERC20 token = IERC20(i_stakeToken);
            uint256 beforeBalance = token.balanceOf(address(this));
            token.safeTransferFrom(msg.sender, address(this), amount);
            uint256 afterBalance = token.balanceOf(address(this));
            if (afterBalance < beforeBalance || afterBalance - beforeBalance != amount) revert UnsupportedTransfer();
        }
    }

    function _sendStake(address recipient, uint256 amount) internal {
        if (amount == 0) return;
        if (i_stakeToken == address(0)) {
            (bool success,) = recipient.call{ value: amount }("");
            if (!success) revert TransferFailed();
        } else {
            IERC20 token = IERC20(i_stakeToken);
            uint256 beforeBalance = token.balanceOf(address(this));
            uint256 beforeRecipient = token.balanceOf(recipient);
            token.safeTransfer(recipient, amount);
            uint256 afterBalance = token.balanceOf(address(this));
            uint256 afterRecipient = token.balanceOf(recipient);
            if (
                afterBalance > beforeBalance || beforeBalance - afterBalance != amount
                    || afterRecipient < beforeRecipient || afterRecipient - beforeRecipient != amount
            ) revert UnsupportedTransfer();
        }
    }
}

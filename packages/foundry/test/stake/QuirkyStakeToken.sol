// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Adversarial ERC20 behaviors are opt-in so failures can be retried after recovery.
contract QuirkyStakeToken is ERC20 {
    uint8 private immutable i_decimals;
    uint256 public fee;
    bool public paused;
    bool public noReturn;
    bool public bonus;
    mapping(address => bool) public blocked;
    address public callbackTarget;
    bytes public callbackData;
    bool public callbackSucceeded;
    bool private s_calling;

    constructor(uint8 tokenDecimals) ERC20("Stake", "STAKE") {
        i_decimals = tokenDecimals;
    }

    function decimals() public view override returns (uint8) {
        return i_decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFee(uint256 amount) external {
        fee = amount;
    }

    function setPaused(bool value) external {
        paused = value;
    }

    function setNoReturn(bool value) external {
        noReturn = value;
    }

    function setBonus(bool value) external {
        bonus = value;
    }

    function setBlocked(address who, bool value) external {
        blocked[who] = value;
    }

    function setCallback(address target, bytes calldata data) external {
        callbackTarget = target;
        callbackData = data;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        super.transfer(to, amount);
        if (noReturn) assembly { return(0, 0) }
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        super.transferFrom(from, to, amount);
        if (noReturn) assembly { return(0, 0) }
        return true;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0)) {
            require(!paused, "paused");
            require(!blocked[from] && !blocked[to], "blocked");
            uint256 charge = fee > amount ? amount : fee;
            super._update(from, to, amount - charge);
            if (charge != 0) super._update(from, address(0), charge);
            if (bonus) super._update(address(0), to, 1);
            if (callbackTarget != address(0) && !s_calling) {
                s_calling = true;
                (callbackSucceeded,) = callbackTarget.call(callbackData);
                s_calling = false;
            }
        } else {
            super._update(from, to, amount);
        }
    }
}

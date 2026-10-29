// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IStakeReceiver {
    function onStakeReceived() external;
}

contract StakeTokenMock is ERC20 {
    mapping(address => bool) public callbacks;
    constructor() ERC20("Stake", "STAKE") { }

    function setBalance(address who, uint256 amount) external {
        uint256 current = balanceOf(who);
        if (amount > current) _mint(who, amount - current);
        else if (amount < current) _burn(who, current - amount);
    }

    function setCallback(address who) external {
        callbacks[who] = true;
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, amount);
        if (from != address(0) && callbacks[to]) IStakeReceiver(to).onStakeReceived();
    }
}

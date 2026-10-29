// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTokenMock } from "../mocks/StakeTokenMock.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";

abstract contract StakeTestBase is Test {
    StakeTokenMock internal stakeToken;
    address[] private markets;

    function usesToken() internal pure virtual returns (bool) {
        return false;
    }

    function _initStakeToken() internal {
        if (usesToken() && address(stakeToken) == address(0)) stakeToken = new StakeTokenMock();
    }

    function _setStakeToken(address token) internal {
        stakeToken = StakeTokenMock(token);
    }

    function _value(uint256 amount) internal view returns (uint256) {
        return address(stakeToken) == address(0) ? amount : 0;
    }

    function _balance(address who) internal view returns (uint256) {
        return address(stakeToken) == address(0) ? who.balance : stakeToken.balanceOf(who);
    }

    function _deal(address who, uint256 amount) internal {
        if (address(stakeToken) == address(0)) vm.deal(who, amount);
        else stakeToken.setBalance(who, amount);
        for (uint256 i; i < markets.length; ++i) {
            _approve(who, markets[i]);
        }
    }

    function _approve(address who, address market) internal {
        if (address(stakeToken) == address(0)) return;
        vm.prank(who);
        stakeToken.approve(market, type(uint256).max);
    }

    function _register(address market, address payer) internal {
        markets.push(market);
        _approve(address(this), market);
        _approve(payer, market);
        _approve(address(0xA11CE), market);
        _approve(address(0xB0B), market);
        _approve(address(0xCA201), market);
        _approve(address(0xCA11), market);
    }

    function _newUpDown(address payer, BasePoolReader reader) internal returns (UpDownRounds market) {
        market = new UpDownRounds(payer, reader, address(stakeToken), 0.01 ether);
        _register(address(market), payer);
    }

    function _newThreshold(address payer, BasePoolReader reader) internal returns (ThresholdPots market) {
        market = new ThresholdPots(payer, reader, address(stakeToken));
        _register(address(market), payer);
    }
}

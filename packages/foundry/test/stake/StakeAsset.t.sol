// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ExactStakeToken is ERC20 {
    constructor() ERC20("Stake", "STAKE") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakeAssetTest is Test {
    function testERC20FundingAndWithdrawalConserveRawUnits() public {
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quote = new MockReadingToken(18, 1e18);
        MockBasePool pool = new MockBasePool(address(base), address(quote));
        BasePoolReader reader = new BasePoolReader(address(pool), address(base), 4);
        ExactStakeToken token = new ExactStakeToken();
        UpDownRounds up = new UpDownRounds(address(this), reader, address(token), 10_000);
        ThresholdPots pot = new ThresholdPots(address(this), reader, address(token));
        token.mint(address(this), 123_456);
        token.approve(address(up), 23_456);
        up.fund(23_456);
        token.approve(address(pot), 100_000);
        pot.fund(100_000);
        assertEq(token.balanceOf(address(this)), 0);
        up.withdrawLiquidity(23_456);
        pot.withdrawFunding(100_000);
        assertEq(token.balanceOf(address(this)), 123_456);
    }
}

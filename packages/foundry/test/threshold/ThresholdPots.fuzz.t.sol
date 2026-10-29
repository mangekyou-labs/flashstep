// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ThresholdPotsFuzzTest is StakeTestBase {
    BasePoolReader reader;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public virtual {
        _initStakeToken();
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quoteToken = new MockReadingToken(18, 1e18);
        MockBasePool pool = new MockBasePool(address(base), address(quoteToken));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
    }

    function settings(uint256 opening, uint256 cap, uint256 threshold)
        internal
        view
        returns (ThresholdPots.CampaignSettings memory)
    {
        return ThresholdPots.CampaignSettings(
            opening, cap, threshold, 10, 4, 110, ThresholdPots.Metric.Price, reader, MarketCapReader(address(0))
        );
    }

    function testFuzzThresholdOpeningAndStakesConserveEveryWei(
        uint256 rawOpening,
        uint256 rawCap,
        uint256 rawThreshold,
        uint256 rawYes,
        uint256 rawNo
    ) public {
        uint256 opening = bound(rawOpening, 0, 1e30);
        uint256 cap = bound(rawCap, 1, 1e30);
        uint256 threshold = bound(rawThreshold, 1, type(uint256).max);
        uint256 yes = bound(rawYes, 1, cap);
        uint256 no = bound(rawNo, 1, cap);
        ThresholdPots market = _newThreshold(address(this), reader);
        _deal(address(this), 2 * opening);
        if (opening != 0) market.fund{ value: _value(2 * opening) }(2 * opening);
        market.seedRound(settings(opening, cap, threshold));
        _deal(alice, yes);
        _deal(bob, no);
        vm.prank(alice);
        market.stake{ value: _value(yes) }(1, ThresholdPots.Side.Yes, yes);
        vm.prank(bob);
        market.stake{ value: _value(no) }(1, ThresholdPots.Side.No, no);
        vm.warp(114);
        vm.roll(17);
        market.captureBoundary(1);
        vm.warp(116);
        vm.roll(18);
        market.settle(1);

        // Native multiplication is safe for this bounded domain and independent of mulDiv.
        uint256 pot = 2 * opening + yes + no;
        uint256 payerExpected;
        uint256 aliceExpected;
        uint256 bobExpected;
        if (threshold == 1e36) {
            payerExpected = 2 * opening;
            aliceExpected = yes;
            bobExpected = no;
        } else {
            uint256 winning = opening + (threshold < 1e36 ? yes : no);
            payerExpected = opening * pot / winning;
            if (threshold < 1e36) aliceExpected = yes * pot / winning;
            else bobExpected = no * pot / winning;
        }
        assertEq(market.claimable(1, address(this)), payerExpected);
        assertEq(market.claim(1), payerExpected);
        vm.prank(alice);
        assertEq(market.claim(1), aliceExpected);
        vm.prank(bob);
        assertEq(market.claim(1), bobExpected);
        assertEq(_balance(alice), aliceExpected);
        assertEq(_balance(bob), bobExpected);
        uint256 dust = pot - payerExpected - aliceExpected - bobExpected;
        assertEq(market.dustCredit(address(this)), dust);
        if (dust != 0) assertEq(market.withdrawDust(), dust);
        assertEq(_balance(address(market)), 0);
        assertEq(_balance(address(this)) + _balance(alice) + _balance(bob), pot);
        assertEq(market.claim(1), 0);
    }

    function testFuzzThresholdNearReading(uint256 opening, uint256 cap, uint256 threshold, uint256 yes, uint256 no)
        public
    {
        testFuzzThresholdOpeningAndStakesConserveEveryWei(
            opening, cap, bound(threshold, 1e36 - 100, 1e36 + 100), yes, no
        );
    }

    function testNumericConfigurationBoundaries() public {
        uint256[5] memory openings = [uint256(0), 1, 2, 1e30 - 1, 1e30];
        uint256[4] memory caps = [uint256(1), 2, 1e30 - 1, 1e30];
        uint256[4] memory thresholds = [uint256(1), 2, type(uint256).max - 1, type(uint256).max];
        for (uint256 i; i < openings.length; ++i) {
            ThresholdPots market = _newThreshold(address(this), reader);
            _deal(address(this), openings[i] * 2);
            if (openings[i] != 0) market.fund{ value: _value(openings[i] * 2) }(openings[i] * 2);
            uint256 cap = caps[i % caps.length];
            market.seedRound(settings(openings[i], cap, thresholds[i % thresholds.length]));
            _deal(alice, cap + 1);
            vm.prank(alice);
            market.stake{ value: _value(cap) }(1, ThresholdPots.Side.Yes, cap);
            vm.expectRevert(ThresholdPots.StakeCapExceeded.selector);
            vm.prank(alice);
            market.stake{ value: _value(1) }(1, ThresholdPots.Side.No, 1);
            assertEq(_balance(address(market)), openings[i] * 2 + cap);
            assertEq(market.positionOf(1, alice).yes, cap);
        }
        uint256[3] memory invalidOpening = [uint256(1e30 + 1), type(uint256).max - 1, type(uint256).max];
        uint256[4] memory invalidCap = [uint256(0), 1e30 + 1, type(uint256).max - 1, type(uint256).max];
        for (uint256 i; i < invalidOpening.length; ++i) {
            ThresholdPots market = _newThreshold(address(this), reader);
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(settings(invalidOpening[i], 1, 1));
        }
        for (uint256 i; i < invalidCap.length; ++i) {
            ThresholdPots market = _newThreshold(address(this), reader);
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(settings(0, invalidCap[i], 1));
        }
        ThresholdPots zeroThreshold = _newThreshold(address(this), reader);
        vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
        zeroThreshold.seedRound(settings(0, 1, 0));
    }

    receive() external payable { }
}

contract ThresholdPotsFuzzTestERC20 is ThresholdPotsFuzzTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

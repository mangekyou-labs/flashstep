// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ThresholdPotsFuzzTest is Test {
    BasePoolReader reader;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
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
        ThresholdPots market = new ThresholdPots(address(this), reader);
        vm.deal(address(this), 2 * opening);
        if (opening != 0) market.fund{ value: 2 * opening }();
        market.seedRound(settings(opening, cap, threshold));
        vm.deal(alice, yes);
        vm.deal(bob, no);
        vm.prank(alice);
        market.stake{ value: yes }(1, ThresholdPots.Side.Yes);
        vm.prank(bob);
        market.stake{ value: no }(1, ThresholdPots.Side.No);
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
        assertEq(alice.balance, aliceExpected);
        assertEq(bob.balance, bobExpected);
        uint256 dust = pot - payerExpected - aliceExpected - bobExpected;
        assertEq(market.dustCredit(address(this)), dust);
        if (dust != 0) assertEq(market.withdrawDust(), dust);
        assertEq(address(market).balance, 0);
        assertEq(address(this).balance + alice.balance + bob.balance, pot);
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
            ThresholdPots market = new ThresholdPots(address(this), reader);
            vm.deal(address(this), openings[i] * 2);
            if (openings[i] != 0) market.fund{ value: openings[i] * 2 }();
            uint256 cap = caps[i % caps.length];
            market.seedRound(settings(openings[i], cap, thresholds[i % thresholds.length]));
            vm.deal(alice, cap + 1);
            vm.prank(alice);
            market.stake{ value: cap }(1, ThresholdPots.Side.Yes);
            vm.expectRevert(ThresholdPots.StakeCapExceeded.selector);
            vm.prank(alice);
            market.stake{ value: 1 }(1, ThresholdPots.Side.No);
            assertEq(address(market).balance, openings[i] * 2 + cap);
            assertEq(market.positionOf(1, alice).yes, cap);
        }
        uint256[3] memory invalidOpening = [uint256(1e30 + 1), type(uint256).max - 1, type(uint256).max];
        uint256[4] memory invalidCap = [uint256(0), 1e30 + 1, type(uint256).max - 1, type(uint256).max];
        for (uint256 i; i < invalidOpening.length; ++i) {
            ThresholdPots market = new ThresholdPots(address(this), reader);
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(settings(invalidOpening[i], 1, 1));
        }
        for (uint256 i; i < invalidCap.length; ++i) {
            ThresholdPots market = new ThresholdPots(address(this), reader);
            vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
            market.seedRound(settings(0, invalidCap[i], 1));
        }
        ThresholdPots zeroThreshold = new ThresholdPots(address(this), reader);
        vm.expectRevert(ThresholdPots.InvalidConfiguration.selector);
        zeroThreshold.seedRound(settings(0, 1, 0));
    }

    receive() external payable { }
}

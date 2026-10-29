// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ThresholdPots } from "../../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../../contracts/readings/MarketCapReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract ThresholdHandler is StakeTestBase {
    uint256 constant CAP = 1e12;
    uint256 constant THRESHOLD = 1e36 + 1;
    ThresholdPots public market;
    BasePoolReader public reader;
    MockBasePool public pool;
    address[4] public actors;
    mapping(uint256 => bool) public tracked;
    mapping(uint256 => mapping(uint256 => uint256)) public yes;
    mapping(uint256 => mapping(uint256 => uint256)) public no;
    mapping(uint256 => mapping(uint256 => bool)) public claimed;
    mapping(uint256 => ThresholdPots.Result) public outcome;
    uint256 public rounds;
    uint256 public stakes;
    uint256 public claims;
    uint256 public settlements;
    uint256 public paid;
    uint256 public added;
    uint256 public fundingWithdrawn;
    uint256 public dustWithdrawn;
    uint256 public clock = 100;
    bool public missingReadings;
    uint256 public refunds;

    constructor(address asset) {
        _setStakeToken(asset);
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quoteToken = new MockReadingToken(18, 1e18);
        pool = new MockBasePool(address(base), address(quoteToken));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 4);
        market = _newThreshold(address(this), reader);
        actors = [address(this), address(0xA11CE), address(0xB0B), address(0xCA11)];
        _deal(address(this), 84);
        market.fund{ value: _value(84) }(84);
        market.seedRound(
            ThresholdPots.CampaignSettings(
                7, CAP, THRESHOLD, 10, 14, 160, ThresholdPots.Metric.Price, reader, MarketCapReader(address(0))
            )
        );
        track(1);
        deposit(1, 1, 2, true);
        deposit(1, 2, 3, false);
        for (uint256 i; i < 5; ++i) {
            advance(1, 50);
        }
        deposit(2, 1, 4, true);
        deposit(2, 2, 1, false);
    }

    function track(uint256 id) internal {
        if (tracked[id]) return;
        tracked[id] = true;
        ++rounds;
        yes[id][0] = 7;
        no[id][0] = 7;
    }

    function deposit(uint256 id, uint256 actor, uint256 amount, bool side) internal {
        address player = actors[actor];
        _deal(player, _balance(player) + amount);
        if (actor != 0) vm.prank(player);
        market.stake{ value: _value(amount) }(id, side ? ThresholdPots.Side.Yes : ThresholdPots.Side.No, amount);
        track(id);
        if (side) yes[id][actor] += amount;
        else no[id][actor] += amount;
        added += amount;
        ++stakes;
    }

    function stake(uint256 rawActor, uint256 rawAmount, bool side) external {
        uint256 id = market.currentRound();
        if (id == 0 || (!tracked[id] && market.fundingBalance() < 14)) return;
        uint256 actor = rawActor % 4;
        uint256 used = yes[id][actor] + no[id][actor] - (tracked[id] && actor == 0 ? 14 : 0);
        if (used == CAP) return;
        deposit(id, actor, bound(rawAmount, 1, CAP - used), side);
    }

    function advance(uint256 rawSteps, int24 rawTick) public {
        uint256 steps = bound(rawSteps, 1, 3);
        int24 tick = int24(bound(int256(rawTick), -200, 200));
        for (uint256 i; i < steps && clock < 240; ++i) {
            clock += 2;
            vm.warp(clock);
            vm.roll(10 + (clock - 100) / 2);
            for (uint256 id = 1; id <= 6; ++id) {
                if (!missingReadings && tracked[id] && clock == 100 + id * 10 + 14) market.captureBoundary(id);
            }
            pool.write(tick);
        }
    }

    function settle() public {
        for (uint256 id = 1; id <= 6; ++id) {
            if (!tracked[id] || outcome[id] != ThresholdPots.Result.None || clock < 100 + id * 10 + 14) continue;
            uint256 endBlock = market.round(id).endBlock;
            uint256 windowEnd = 100 + id * 10 + 14;
            if (endBlock == 0 && clock < windowEnd + 60) continue;
            market.settle(id);
            if (clock >= windowEnd + 24 hours || endBlock == 0) {
                outcome[id] = ThresholdPots.Result.Refunded;
                ++refunds;
            } else {
                uint256 value = reader.read(endBlock).price;
                outcome[id] = value > THRESHOLD
                    ? ThresholdPots.Result.Yes
                    : value < THRESHOLD ? ThresholdPots.Result.No : ThresholdPots.Result.Tie;
            }
            assertEq(uint256(market.round(id).result), uint256(outcome[id]));
            ++settlements;
        }
    }

    function entitlement(uint256 id, uint256 actor) public view returns (uint256) {
        uint256 y;
        uint256 n;
        for (uint256 a; a < 4; ++a) {
            y += yes[id][a];
            n += no[id][a];
        }
        if (outcome[id] == ThresholdPots.Result.Yes) return yes[id][actor] * (y + n) / y;
        if (outcome[id] == ThresholdPots.Result.No) return no[id][actor] * (y + n) / n;
        return yes[id][actor] + no[id][actor];
    }

    function claim(uint256 rawId, uint256 rawActor) public {
        uint256 id = rawId % 6 + 1;
        uint256 actor = rawActor % 4;
        if (tracked[id] && outcome[id] == ThresholdPots.Result.None && market.phase(id) == ThresholdPots.Phase.Refunded)
        {
            outcome[id] = ThresholdPots.Result.Refunded;
            ++refunds;
            ++settlements;
        }
        if (outcome[id] == ThresholdPots.Result.None) return;
        uint256 expected = claimed[id][actor] ? 0 : entitlement(id, actor);
        assertEq(market.claimable(id, actors[actor]), expected);
        uint256 beforeBalance = _balance(actors[actor]);
        if (actor != 0) vm.prank(actors[actor]);
        assertEq(market.claim(id), expected);
        assertEq(_balance(actors[actor]) - beforeBalance, expected);
        claimed[id][actor] = true;
        paid += expected;
        if (expected != 0) ++claims;
    }

    function withdrawFunding(uint256 rawAmount) public {
        uint256 available = 84 - rounds * 14 - fundingWithdrawn;
        if (available == 0) return;
        uint256 amount = bound(rawAmount, 1, available);
        uint256 beforeBalance = _balance(address(this));
        market.withdrawFunding(amount);
        assertEq(_balance(address(this)) - beforeBalance, amount);
        fundingWithdrawn += amount;
    }

    function withdrawDust() public {
        uint256 beforeBalance = _balance(address(this));
        uint256 amount = market.withdrawDust();
        assertEq(_balance(address(this)) - beforeBalance, amount);
        dustWithdrawn += amount;
    }

    function outage(bool missing) external {
        missingReadings = missing;
    }

    function expire() external {
        clock += 24 hours;
        vm.warp(clock);
        vm.roll(10 + (clock - 100) / 2);
    }

    function assertAccounting(bool allSettled) public view {
        uint256 unpaid;
        uint256 dust;
        uint256 pending;
        for (uint256 id = 1; id <= 6; ++id) {
            if (!tracked[id]) continue;
            uint256 pot;
            uint256 payouts;
            for (uint256 actor; actor < 4; ++actor) {
                pot += yes[id][actor] + no[id][actor];
                if (outcome[id] != ThresholdPots.Result.None) {
                    uint256 amount = entitlement(id, actor);
                    payouts += amount;
                    uint256 remaining = claimed[id][actor] ? 0 : amount;
                    assertEq(market.claimable(id, actors[actor]), remaining);
                    unpaid += remaining;
                }
            }
            if (outcome[id] == ThresholdPots.Result.None) pending += pot;
            else dust += pot - payouts;
        }
        uint256 funding = 84 - rounds * 14 - fundingWithdrawn;
        assertEq(market.fundingBalance(), funding);
        assertEq(_balance(address(market)), funding + pending + unpaid + dust - dustWithdrawn);
        assertEq(_balance(address(market)), 84 + added - paid - fundingWithdrawn - dustWithdrawn);
        if (allSettled) {
            assertEq(funding + pending, 0);
            assertEq(_balance(address(market)), unpaid + dust - dustWithdrawn);
        }
    }

    function finish() external {
        while (clock < 240) advance(1, 50);
        settle();
        withdrawFunding(type(uint256).max);
        assertAccounting(true);
        for (uint256 id = 1; id <= 6; ++id) {
            for (uint256 actor; actor < 4; ++actor) {
                claim(id - 1, actor);
            }
        }
        withdrawDust();
        assertEq(_balance(address(market)), 0);
        assertGe(stakes, 4);
        assertGe(settlements, 2);
        assertGe(claims, 2);
        emit log_named_uint("refunded books", refunds);
    }
    receive() external payable { }
}

contract ThresholdPotsInvariantTest is StdInvariant, StakeTestBase {
    ThresholdHandler handler;

    function setUp() public virtual {
        _initStakeToken();
        handler = new ThresholdHandler(address(stakeToken));
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.stake.selector;
        selectors[1] = handler.advance.selector;
        selectors[2] = handler.settle.selector;
        selectors[3] = handler.claim.selector;
        selectors[4] = handler.withdrawFunding.selector;
        selectors[5] = handler.withdrawDust.selector;
        selectors[6] = handler.outage.selector;
        selectors[7] = handler.expire.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }

    function invariantCustodyMatchesIndependentClaimsAndDust() public view {
        handler.assertAccounting(false);
    }

    function afterInvariant() public {
        handler.finish();
    }
}

contract ThresholdPotsInvariantTestERC20 is ThresholdPotsInvariantTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

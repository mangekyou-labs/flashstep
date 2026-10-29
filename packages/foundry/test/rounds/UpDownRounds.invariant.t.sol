// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract RoundHandler is StakeTestBase {
    UpDownRounds public market;
    MockBasePool public pool;
    uint256 public stakes;
    uint256 public claims;
    uint256 public buys;
    uint256 public paidClaims;
    address[3] public players = [address(0xA11CE), address(0xB0B), address(0xCA11)];

    constructor(UpDownRounds market_, MockBasePool pool_) {
        market = market_;
        _setStakeToken(market_.i_stakeToken());
        _register(address(market_), address(this));
        pool = pool_;
    }

    function buy(uint256 rawPlayer, uint256 rawShares, bool up) external {
        if (market.phase(1) != UpDownRounds.Phase.Trading) return;
        if (buys < 2) up = buys == 0;
        UpDownRounds.Round memory r = market.round(1);
        uint256 reserve = r.sharesPerSide - (up ? r.upSold : r.downSold);
        if (reserve < 100) return;
        uint256 shares = bound(rawShares, 100, reserve);
        address player = players[rawPlayer % 3];
        UpDownRounds.Side side = up ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
        uint256 cost = market.quote(1, side, shares);
        _deal(player, _balance(player) + cost);
        uint256 beforeBalance = _balance(player);
        vm.prank(player);
        market.buy{ value: _value(cost) }(1, side, shares, cost);
        stakes += beforeBalance - _balance(player);
        ++buys;
    }

    function advance(bool up, bool tie) external {
        if (buys < 2) return;
        UpDownRounds.Phase p = market.phase(1);
        if (p == UpDownRounds.Phase.Trading) {
            vm.warp(110);
            vm.roll(15);
            market.captureBoundary(1);
            pool.write(tie ? int24(0) : up ? int24(100) : int24(-100));
        } else if (p == UpDownRounds.Phase.Window) {
            vm.warp(114);
            vm.roll(17);
            market.captureBoundary(1);
        }
    }

    function settle() external {
        if (market.phase(1) == UpDownRounds.Phase.AwaitingSettlement) market.settle(1);
    }

    function claim(uint256 rawPlayer) external {
        if (market.phase(1) != UpDownRounds.Phase.Settled) return;
        address player = players[rawPlayer % 3];
        uint256 beforeBalance = _balance(player);
        vm.prank(player);
        market.claim(1);
        uint256 received = _balance(player) - beforeBalance;
        claims += received;
        if (received != 0) ++paidClaims;
    }
}

contract UpDownRoundsInvariantTest is StdInvariant, StakeTestBase {
    RoundHandler handler;
    UpDownRounds market;

    function setUp() public virtual {
        _initStakeToken();
        vm.warp(100);
        vm.roll(10);
        MockReadingToken base = new MockReadingToken(18, 1e18);
        MockReadingToken quoteToken = new MockReadingToken(18, 1e18);
        MockBasePool pool = new MockBasePool(address(base), address(quoteToken));
        pool.write(0);
        BasePoolReader reader = new BasePoolReader(address(pool), address(base), 4);
        market = _newUpDown(address(this), reader);
        _deal(address(this), 1 ether);
        market.fund{ value: _value(1 ether) }(1 ether);
        market.seedRound(1 ether, 100 ether, 10, 4);
        handler = new RoundHandler(market, pool);
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.advance.selector;
        selectors[2] = handler.settle.selector;
        selectors[3] = handler.claim.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }

    function afterInvariant() public {
        emit log_named_uint("successful buys in final sequence", handler.buys());
        emit log_named_uint("paid claims in final sequence", handler.paidClaims());
    }

    function invariantETHHeldEqualsSeedPlusStakesMinusPaidClaims() public view {
        assertEq(_balance(address(market)), 1 ether + handler.stakes() - handler.claims());
    }

    function invariantEveryOutstandingWinningClaimIsBacked() public view {
        uint256 owed;
        for (uint256 i; i < 3; ++i) {
            owed += market.claimable(1, handler.players(i));
        }
        assertLe(owed, _balance(address(market)));
    }
}

contract UpDownRoundsInvariantTestERC20 is UpDownRoundsInvariantTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

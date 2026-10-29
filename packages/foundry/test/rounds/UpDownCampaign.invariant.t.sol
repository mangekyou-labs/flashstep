// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { Test } from "forge-std/Test.sol";
import { StakeTestBase } from "../stake/StakeTestBase.sol";
import { StakeAsset } from "../../contracts/StakeAsset.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { UpDownRounds } from "../../contracts/UpDownRounds.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

contract CampaignHandler is StakeTestBase {
    UpDownRounds public market;
    BasePoolReader public reader;
    MockBasePool public pool;
    address[3] public players = [address(0xA11CE), address(0xB0B), address(0xCA11)];
    uint256[] public rounds;
    mapping(uint256 => bool) tracked;
    mapping(uint256 => uint256) public escrow;
    mapping(uint256 => mapping(address => uint256)) public paid;
    mapping(uint256 => mapping(address => uint256)) public soldFor;
    uint256 public stakes;
    uint256 public sellPayments;
    uint256 public claims;
    uint256 public withdrawals;
    uint256 public successfulBuys;
    uint256 public successfulSells;
    uint256 public successfulClaims;
    uint256 public successfulSettlements;
    uint256 public expectedRefusals;
    uint256 public clock = 100;
    uint256 public height = 10;

    constructor(BasePoolReader reader_, MockBasePool pool_, address asset) payable {
        _setStakeToken(asset);
        _deal(address(this), 12 ether);
        reader = reader_;
        pool = pool_;
        market = _newUpDown(address(this), reader);
        market.fund{ value: _value(12 ether) }(12 ether);
        market.seedRound(1 ether, 1e30, 10, 4);
        market.setCampaignSettings(1 ether, 1e30, 10, 14, 260, reader);
        _track(1);
    }

    function roundCount() external view returns (uint256) {
        return rounds.length;
    }

    function _track(uint256 id) private {
        if (tracked[id]) return;
        tracked[id] = true;
        rounds.push(id);
        escrow[id] = market.round(id).seededLiquidity;
    }

    function buy(uint256 rawPlayer, uint256 rawShares, bool up) external {
        uint256 id = market.currentRound();
        if (id == 0) return;
        UpDownRounds.Round memory r = market.round(id);
        if (r.collateral == 0 && market.fundingBalance() < r.seededLiquidity) return;
        UpDownRounds.Side side = up ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
        uint256 reserve = r.sharesPerSide - (up ? r.upSold : r.downSold);
        if (reserve == 0) return;
        uint256 shares = bound(rawShares, 1, reserve);
        uint256 cost = market.quote(id, side, shares);
        address player = players[rawPlayer % 3];
        _deal(player, _balance(player) + cost);
        uint256 beforeBalance = _balance(player);
        vm.prank(player);
        try market.buy{ value: _value(cost) }(id, side, shares, cost) {
            _track(id);
            uint256 sent = beforeBalance - _balance(player);
            escrow[id] += sent;
            paid[id][player] += sent;
            stakes += sent;
            ++successfulBuys;
        } catch (bytes memory reason) {
            assertTrue(
                bytes4(reason) == UpDownRounds.StakeCapExceeded.selector
                    || bytes4(reason) == UpDownRounds.InsufficientReserve.selector
            );
            assertEq(_balance(player), beforeBalance);
            ++expectedRefusals;
        }
    }

    function sell(uint256 rawPlayer, uint256 rawShares, bool up) external {
        uint256 id = market.currentRound();
        if (id == 0 || !tracked[id]) return;
        address player = players[rawPlayer % 3];
        UpDownRounds.Position memory p = market.positionOf(id, player);
        uint256 owned = up ? p.up : p.down;
        if (owned == 0) return;
        uint256 shares = bound(rawShares, 1, owned);
        UpDownRounds.Side side = up ? UpDownRounds.Side.Up : UpDownRounds.Side.Down;
        uint256 proceeds = market.quoteSell(id, side, shares);
        uint256 beforeBalance = _balance(player);
        vm.prank(player);
        try market.sell(id, side, shares, proceeds) {
            uint256 received = _balance(player) - beforeBalance;
            escrow[id] -= received;
            soldFor[id][player] += received;
            sellPayments += received;
            ++successfulSells;
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), UpDownRounds.InsufficientReserve.selector);
            assertEq(_balance(player), beforeBalance);
            ++expectedRefusals;
        }
    }

    function advance(uint256 rawSteps, int24 rawTick) external {
        uint256 steps = bound(rawSteps, 1, 3);
        for (uint256 step; step < steps && clock < 300; ++step) {
            clock += 2;
            vm.warp(clock);
            vm.roll(++height);
            _captureBoundaries();
            pool.write(int24(bound(int256(rawTick), -200, 200)));
        }
    }

    function _captureBoundaries() private {
        for (uint256 i; i < rounds.length; ++i) {
            uint256 id = rounds[i];
            UpDownRounds.Round memory r = market.round(id);
            if (r.result == UpDownRounds.Result.None && (clock == r.cutoff || clock == r.windowEnd)) {
                market.captureBoundary(id);
            }
        }
    }

    function settle() public {
        for (uint256 i; i < rounds.length; ++i) {
            uint256 id = rounds[i];
            UpDownRounds.Round memory r = market.round(id);
            if (r.result == UpDownRounds.Result.None && clock >= r.windowEnd) {
                market.settle(id);
                ++successfulSettlements;
            }
        }
    }

    function claim(uint256 rawPlayer, uint256 rawRound) external {
        address player = players[rawPlayer % 3];
        uint256 id = rounds[rawRound % rounds.length];
        if (market.phase(id) != UpDownRounds.Phase.Settled) return;
        uint256 beforeBalance = _balance(player);
        vm.prank(player);
        market.claim(id);
        uint256 received = _balance(player) - beforeBalance;
        claims += received;
        if (received != 0) ++successfulClaims;
    }

    function withdraw(uint256 rawAmount) external {
        uint256 available = market.fundingBalance();
        if (available == 0) return;
        uint256 beforeBalance = _balance(address(this));
        market.withdrawLiquidity(bound(rawAmount, 1, available));
        withdrawals += _balance(address(this)) - beforeBalance;
    }

    function configure(uint256 rawSeed, uint256 rawCap, uint256 rawTrading, uint256 rawWindow) external {
        uint256 id = market.currentRound();
        if (market.stopped() || id == 0 || market.round(id).cutoff >= 260) return;
        uint32 trading = uint32(2 * bound(rawTrading, 3, 15));
        uint32 window = uint32(2 * bound(rawWindow, 1, 15));
        market.setCampaignSettings(bound(rawSeed, 1e16, 2 ether), bound(rawCap, 1, 1e30), trading, window, 260, reader);
    }

    function stop() external {
        if (!market.stopped()) market.stopCampaign();
    }

    function finishAll() external {
        if (!market.stopped()) market.stopCampaign();
        while (clock < 340) {
            clock += 2;
            vm.warp(clock);
            vm.roll(++height);
            _captureBoundaries();
        }
        settle();
    }

    receive() external payable { }
}

contract UpDownCampaignInvariantTest is StdInvariant, StakeTestBase {
    CampaignHandler handler;
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
        _deal(address(this), 12 ether);
        handler = new CampaignHandler{ value: _value(12 ether) }(reader, pool, address(stakeToken));
        market = handler.market();
        // Every search starts with real buys and sells in two overlapping books.
        handler.buy(0, 2e18, true);
        handler.sell(0, 1e18, true);
        handler.advance(3, 100);
        handler.advance(2, 100);
        handler.buy(1, 2e18, false);
        handler.sell(1, 1e18, false);
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = handler.buy.selector;
        selectors[1] = handler.sell.selector;
        selectors[2] = handler.advance.selector;
        selectors[3] = handler.settle.selector;
        selectors[4] = handler.claim.selector;
        selectors[5] = handler.withdraw.selector;
        selectors[6] = handler.configure.selector;
        selectors[7] = handler.stop.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }

    function invariantHeldEqualsUnresolvedEscrowPlusClaimsPlusWithdrawableLiquidity() public view {
        uint256 escrow;
        uint256 owed;
        for (uint256 i; i < handler.roundCount(); ++i) {
            uint256 id = handler.rounds(i);
            UpDownRounds.Round memory r = market.round(id);
            if (r.result == UpDownRounds.Result.None) {
                uint256 independentEscrow = handler.escrow(id);
                assertEq(r.collateral, independentEscrow);
                escrow += independentEscrow;
            } else {
                uint256 roundOwed;
                for (uint256 player; player < 3; ++player) {
                    roundOwed += market.claimable(id, handler.players(player));
                }
                assertEq(r.collateral, roundOwed);
                owed += roundOwed;
            }
        }
        assertEq(_balance(address(market)), escrow + owed + market.fundingBalance());
    }

    function invariantEveryWeiHasObservedSourceAndDestination() public view {
        assertEq(
            _balance(address(market)),
            12 ether + handler.stakes() - handler.sellPayments() - handler.claims() - handler.withdrawals()
        );
    }

    function afterInvariant() public {
        handler.finishAll();
        uint256 owed;
        for (uint256 i; i < handler.roundCount(); ++i) {
            uint256 id = handler.rounds(i);
            for (uint256 player; player < 3; ++player) {
                address account = handler.players(player);
                uint256 claim = market.claimable(id, account);
                if (market.round(id).result == UpDownRounds.Result.Tie && !market.positionOf(id, account).claimed) {
                    uint256 bought = handler.paid(id, account);
                    uint256 proceeds = handler.soldFor(id, account);
                    assertEq(claim, bought > proceeds ? bought - proceeds : 0);
                }
                owed += claim;
            }
        }
        // Once every book settles, this is the ticket's literal equality: no locked reserve remains.
        assertEq(_balance(address(market)), owed + market.fundingBalance());
        handler.withdraw(type(uint256).max);
        assertEq(_balance(address(market)), owed);
        for (uint256 i; i < handler.roundCount(); ++i) {
            for (uint256 player; player < 3; ++player) {
                handler.claim(player, i);
            }
        }
        assertEq(_balance(address(market)), 0);
        assertGe(handler.successfulBuys(), 2);
        assertGe(handler.successfulSells(), 2);
        assertGe(handler.successfulSettlements(), 2);
        emit log_named_uint("successful buys", handler.successfulBuys());
        emit log_named_uint("successful sells", handler.successfulSells());
        emit log_named_uint("paid claims", handler.successfulClaims());
        emit log_named_uint("settled books", handler.successfulSettlements());
        emit log_named_uint("expected cap/backing refusals", handler.expectedRefusals());
    }
}

contract UpDownCampaignInvariantTestERC20 is UpDownCampaignInvariantTest {
    function usesToken() internal pure override returns (bool) {
        return true;
    }
}

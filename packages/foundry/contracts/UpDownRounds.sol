// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "./readings/BasePoolReader.sol";

/// @notice First ETH Round slice: one share book, capped buys and block-pinned TWAP settlement.
contract UpDownRounds is Ownable, ReentrancyGuard {
    enum Side {
        Up,
        Down
    }
    enum Phase {
        Trading,
        Window,
        AwaitingSettlement,
        Settled
    }
    enum Result {
        None,
        Up,
        Down,
        Tie
    }

    struct Position {
        uint256 up;
        uint256 down;
        uint256 paid;
        bool claimed;
    }

    struct Round {
        uint256 cutoff;
        uint256 windowEnd;
        uint256 stakeCap;
        uint256 seededLiquidity;
        uint256 sharesPerSide;
        uint256 upSold;
        uint256 downSold;
        uint256 startBlock;
        uint256 endBlock;
        Result result;
        BasePoolReader.Reading startReading;
        BasePoolReader.Reading endReading;
    }
    error InvalidConfiguration();
    error UnknownRound();
    error RoundAlreadySeeded();
    error InsufficientFunding();
    error OutsideTrading();
    error StakeCapExceeded();
    error InsufficientReserve();
    error SlippageExceeded();
    error IncorrectPayment();
    error InvalidAmount();
    error PayerCannotBuy();
    error OutsideBoundary();
    error NoValidReading();
    error TooEarlyToSettle();
    error AlreadySettled();
    error NotSettled();
    error TransferFailed();

    uint256 public constant SHARE_SCALE = 1e18;
    uint256 public constant PAYOUT = 0.01 ether;
    uint256 public constant MIN_SEED = 0.01 ether;
    uint256 public constant MAX_SEED = 1e30;
    uint256 public constant MAX_STAKE_CAP = 1e30;
    BasePoolReader public immutable i_reader;
    uint256 public fundingBalance;
    mapping(uint256 => Round) private s_rounds;
    mapping(uint256 => mapping(address => Position)) private s_positions;
    bool private s_seeded;

    event Funded(address indexed payer, uint256 amount);
    event RoundSeeded(uint256 indexed roundId, uint256 seed, uint256 cutoff, uint256 windowEnd, uint256 stakeCap);
    event Bought(uint256 indexed roundId, address indexed player, Side side, uint256 shares, uint256 cost);
    event BoundaryCaptured(uint256 indexed roundId, bool start, uint256 blockNumber);
    event Settled(uint256 indexed roundId, Result result, uint256 startPrice, uint256 endPrice);
    event Claimed(uint256 indexed roundId, address indexed player, uint256 amount);

    constructor(address payer, BasePoolReader reader) Ownable(payer) {
        if (address(reader).code.length == 0) revert InvalidConfiguration();
        i_reader = reader;
    }

    function fund() external payable onlyOwner {
        if (msg.value == 0) revert InvalidAmount();
        fundingBalance += msg.value;
        emit Funded(msg.sender, msg.value);
    }

    /// @notice Seed the one Round from prefunded ETH. Timing is fixed from this transaction.
    function seedRound(uint256 seed, uint256 stakeCap, uint32 tradingSeconds, uint32 windowSeconds) external onlyOwner {
        if (s_seeded) revert RoundAlreadySeeded();
        if (
            seed < MIN_SEED || seed > MAX_SEED || stakeCap == 0 || stakeCap > MAX_STAKE_CAP || tradingSeconds < 5
                || tradingSeconds > 30 || windowSeconds == 0 || windowSeconds > 30
        ) {
            revert InvalidConfiguration();
        }
        if (seed > fundingBalance) revert InsufficientFunding();
        s_seeded = true;
        fundingBalance -= seed;
        Round storage r = s_rounds[1];
        r.cutoff = block.timestamp + tradingSeconds;
        r.windowEnd = r.cutoff + windowSeconds;
        r.stakeCap = stakeCap;
        r.seededLiquidity = seed;
        r.sharesPerSide = Math.mulDiv(seed, SHARE_SCALE, PAYOUT);
        // The Speedrun opening lock sets a symmetric 50-cent chance and never belongs to a Player.
        r.upSold = r.sharesPerSide / 10;
        r.downSold = r.upSold;
        emit RoundSeeded(1, seed, r.cutoff, r.windowEnd, stakeCap);
    }

    function phase(uint256 roundId) public view returns (Phase) {
        Round storage r = _round(roundId);
        if (r.result != Result.None) return Phase.Settled;
        if (block.timestamp < r.cutoff) return Phase.Trading;
        if (block.timestamp < r.windowEnd) return Phase.Window;
        return Phase.AwaitingSettlement;
    }

    function round(uint256 roundId) external view returns (Round memory) {
        return _round(roundId);
    }

    function positionOf(uint256 roundId, address player) external view returns (Position memory) {
        _round(roundId);
        return s_positions[roundId][player];
    }

    /// @notice ETH cost for exact shares, using Speedrun's average before/after sold-share chance.
    /// Shares use 18 decimals, ETH uses wei. Cost rounds upward to avoid free dust buys.
    function quote(uint256 roundId, Side side, uint256 shares) public view returns (uint256) {
        Round storage r = _round(roundId);
        if (shares == 0) revert InvalidAmount();
        uint256 sold = side == Side.Up ? r.upSold : r.downSold;
        if (shares > r.sharesPerSide - sold) revert InsufficientReserve();
        uint256 total = r.upSold + r.downSold;
        uint256 beforeChance = Math.mulDiv(sold, SHARE_SCALE, total);
        uint256 afterChance = Math.mulDiv(sold + shares, SHARE_SCALE, total + shares);
        return
            Math.mulDiv(
                shares, PAYOUT * (beforeChance + afterChance), 2 * SHARE_SCALE * SHARE_SCALE, Math.Rounding.Ceil
            );
    }

    /// @notice Pay exactly the current quote; maxCost protects a pending exact-share order.
    /// The cutoff is the deadline. Requote and send a fresh transaction if the cost changes.
    function buy(uint256 roundId, Side side, uint256 shares, uint256 maxCost) external payable nonReentrant {
        if (phase(roundId) != Phase.Trading) revert OutsideTrading();
        if (msg.sender == owner()) revert PayerCannotBuy();
        uint256 cost = quote(roundId, side, shares);
        if (cost > maxCost) revert SlippageExceeded();
        if (msg.value != cost) revert IncorrectPayment();
        Round storage r = s_rounds[roundId];
        Position storage p = s_positions[roundId][msg.sender];
        if (p.paid + cost > r.stakeCap) revert StakeCapExceeded();
        p.paid += cost;
        if (side == Side.Up) {
            p.up += shares;
            r.upSold += shares;
        } else {
            p.down += shares;
            r.downSold += shares;
        }
        emit Bought(roundId, msg.sender, side, shares, cost);
    }

    /// @notice Anyone must capture at the scheduled boundary timestamp. A late price is never substituted.
    function captureBoundary(uint256 roundId) external nonReentrant {
        Round storage r = _round(roundId);
        if (r.result != Result.None) revert AlreadySettled();
        bool start = block.timestamp == r.cutoff;
        if (!start && block.timestamp != r.windowEnd) revert OutsideBoundary();
        if ((start ? r.startBlock : r.endBlock) != 0) return;
        BasePoolReader.Reading memory reading = i_reader.capture();
        if (reading.timestamp != block.timestamp) revert NoValidReading();
        if (start) r.startBlock = reading.blockNumber;
        else r.endBlock = reading.blockNumber;
        emit BoundaryCaptured(roundId, start, reading.blockNumber);
    }

    function settle(uint256 roundId) external nonReentrant {
        Round storage r = _round(roundId);
        if (block.timestamp < r.windowEnd) revert TooEarlyToSettle();
        if (r.result != Result.None) revert AlreadySettled();
        if (r.startBlock == 0 || r.endBlock == 0) revert NoValidReading();
        BasePoolReader.Reading memory start = i_reader.read(r.startBlock);
        BasePoolReader.Reading memory end = i_reader.read(r.endBlock);
        if (start.timestamp != r.cutoff || end.timestamp != r.windowEnd) revert NoValidReading();
        r.startReading = start;
        r.endReading = end;
        r.result = end.price > start.price ? Result.Up : end.price < start.price ? Result.Down : Result.Tie;
        emit Settled(roundId, r.result, start.price, end.price);
    }

    function claimable(uint256 roundId, address player) public view returns (uint256) {
        Round storage r = _round(roundId);
        Position storage p = s_positions[roundId][player];
        if (p.claimed || r.result == Result.None) return 0;
        if (r.result == Result.Tie) return p.paid;
        return Math.mulDiv(r.result == Result.Up ? p.up : p.down, PAYOUT, SHARE_SCALE);
    }

    function claim(uint256 roundId) external nonReentrant returns (uint256 amount) {
        if (_round(roundId).result == Result.None) revert NotSettled();
        amount = claimable(roundId, msg.sender);
        if (amount == 0) return 0;
        s_positions[roundId][msg.sender].claimed = true;
        emit Claimed(roundId, msg.sender, amount);
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    function _round(uint256 roundId) private view returns (Round storage r) {
        if (roundId != 1 || !s_seeded) revert UnknownRound();
        return s_rounds[roundId];
    }
}

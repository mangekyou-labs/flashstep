// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { StakeAsset } from "./StakeAsset.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "./readings/BasePoolReader.sol";

/// @notice Stake-token Campaigns with scheduled share books and block-pinned TWAP settlement.
contract UpDownRounds is Ownable, ReentrancyGuard, StakeAsset {
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
        uint256 bought;
        uint256 proceeds;
    }

    struct Round {
        BasePoolReader reader;
        uint256 cutoff;
        uint256 windowEnd;
        uint256 stakeCap;
        uint256 seededLiquidity;
        uint256 sharesPerSide;
        uint256 upSold;
        uint256 downSold;
        uint256 startBlock;
        uint256 endBlock;
        uint256 collateral;
        uint256 upLiability;
        uint256 downLiability;
        uint256 refundLiability;
        Result result;
        BasePoolReader.Reading startReading;
        BasePoolReader.Reading endReading;
    }

    struct CampaignSettings {
        uint256 seed;
        uint256 stakeCap;
        uint32 tradingSeconds;
        uint32 windowSeconds;
        uint64 endTime;
        BasePoolReader reader;
    }

    struct Schedule {
        uint256 firstRound;
        uint256 start;
        CampaignSettings settings;
    }

    error CampaignStopped();
    error InvalidConfiguration();
    error UnknownRound();
    error RoundAlreadySeeded();
    error InsufficientFunding();
    error OutsideTrading();
    error StakeCapExceeded();
    error InsufficientReserve();
    error SlippageExceeded();
    error InvalidAmount();
    error PayerCannotBuy();
    error InsufficientShares();
    error OutsideBoundary();
    error NoValidReading();
    error TooEarlyToSettle();
    error AlreadySettled();
    error NotSettled();

    /// @notice Supported Base block cadence; durations must preserve exact boundary timestamps.
    uint256 public constant BLOCK_INTERVAL = 2;
    uint256 public constant SHARE_SCALE = 1e18;
    uint256 private immutable i_payout;
    uint256 public constant MAX_SEED = 1e30;
    uint256 public constant MAX_STAKE_CAP = 1e30;
    BasePoolReader public immutable i_reader;
    uint256 public fundingBalance;
    uint256 public reservedBalance;
    mapping(uint256 => Round) private s_rounds;
    mapping(uint256 => mapping(address => Position)) private s_positions;
    bool private s_seeded;
    Schedule[] private s_schedule;
    uint256 public stopAfter;
    bool public stopped;

    event Funded(address indexed payer, uint256 amount);
    event CampaignStopScheduled(uint256 cutoff);
    event SettingsScheduled(uint256 indexed firstRound, uint256 start, CampaignSettings settings);
    event LiquidityWithdrawn(address indexed payer, uint256 amount);
    event RoundSeeded(uint256 indexed roundId, uint256 seed, uint256 cutoff, uint256 windowEnd, uint256 stakeCap);
    event Bought(uint256 indexed roundId, address indexed player, Side side, uint256 shares, uint256 cost);
    event Sold(uint256 indexed roundId, address indexed player, Side side, uint256 shares, uint256 proceeds);
    event BoundaryCaptured(uint256 indexed roundId, bool start, uint256 blockNumber);
    event Settled(uint256 indexed roundId, Result result, uint256 startPrice, uint256 endPrice);
    event Claimed(uint256 indexed roundId, address indexed player, uint256 amount);

    constructor(address payer, BasePoolReader reader, address stakeToken, uint256 payout)
        Ownable(payer)
        StakeAsset(stakeToken)
    {
        if (payout == 0 || payout > MAX_SEED) revert InvalidConfiguration();
        i_payout = payout;
        if (address(reader).code.length == 0) revert InvalidConfiguration();
        i_reader = reader;
    }

    /// @notice Raw stake-token units paid for one whole winning share.
    function PAYOUT() external view returns (uint256) {
        return i_payout;
    }

    /// @notice Smallest seed, equal to the payout for one whole share.
    function MIN_SEED() external view returns (uint256) {
        return i_payout;
    }

    function fund(uint256 amount) external payable onlyOwner nonReentrant {
        if (amount == 0) revert InvalidAmount();
        fundingBalance += amount;
        _takeStake(amount);
        emit Funded(msg.sender, amount);
    }

    /// @notice Start the Campaign and seed its first Round from prefunded stake tokens.
    function seedRound(uint256 seed, uint256 stakeCap, uint32 tradingSeconds, uint32 windowSeconds) external onlyOwner {
        if (s_seeded) revert RoundAlreadySeeded();
        CampaignSettings memory settings =
            CampaignSettings(seed, stakeCap, tradingSeconds, windowSeconds, type(uint64).max, i_reader);
        _validateSettings(settings);
        s_seeded = true;
        s_schedule.push(Schedule(1, block.timestamp, settings));
        _materialize(1);
    }

    /// @notice The scheduled trading Round, including one that has not received a transaction.
    /// Returns zero before initialization or after the final scheduled Trading phase.
    /// A Round whose start precedes endTime finishes its entire Trading phase.
    function currentRound() public view returns (uint256) {
        if (!s_seeded) return 0;
        uint256 index = _scheduleAtTime(block.timestamp);
        Schedule storage schedule = s_schedule[index];
        CampaignSettings storage settings = schedule.settings;
        uint256 offset = (block.timestamp - schedule.start) / settings.tradingSeconds;
        uint256 start = schedule.start + offset * settings.tradingSeconds;
        if (start >= settings.endTime || (stopped && start >= stopAfter)) return 0;
        return schedule.firstRound + offset;
    }

    /// @notice Queue settings at the current trading cutoff; existing Rounds keep snapshots.
    function setCampaignSettings(
        uint256 seed,
        uint256 stakeCap,
        uint32 tradingSeconds,
        uint32 windowSeconds,
        uint64 endTime,
        BasePoolReader reader
    ) external onlyOwner {
        if (stopped) revert CampaignStopped();
        uint256 active = currentRound();
        if (active == 0) revert InvalidConfiguration();
        Round memory current = _viewRound(active);
        CampaignSettings memory settings =
            CampaignSettings(seed, stakeCap, tradingSeconds, windowSeconds, endTime, reader);
        _validateSettings(settings);
        if (endTime <= current.cutoff) revert InvalidConfiguration();
        Schedule memory next = Schedule(active + 1, current.cutoff, settings);
        uint256 last = s_schedule.length - 1;
        if (s_schedule[last].firstRound == active + 1) s_schedule[last] = next;
        else s_schedule.push(next);
        emit SettingsScheduled(active + 1, current.cutoff, settings);
    }

    /// @notice Irreversible: finish the trading Round already on the schedule, then open none.
    function stopCampaign() external onlyOwner {
        if (stopped) revert CampaignStopped();
        uint256 active = currentRound();
        stopAfter = active == 0 ? block.timestamp : _viewRound(active).cutoff;
        stopped = true;
        emit CampaignStopScheduled(stopAfter);
    }

    function phase(uint256 roundId) public view returns (Phase) {
        Round memory r = _viewRound(roundId);
        if (r.result != Result.None) return Phase.Settled;
        if (block.timestamp < r.cutoff) return Phase.Trading;
        if (block.timestamp < r.windowEnd) return Phase.Window;
        return Phase.AwaitingSettlement;
    }

    function round(uint256 roundId) external view returns (Round memory) {
        return _viewRound(roundId);
    }

    function positionOf(uint256 roundId, address player) external view returns (Position memory) {
        _viewRound(roundId);
        return s_positions[roundId][player];
    }

    /// @notice Stake-token cost for exact shares, using Speedrun's average before/after sold-share chance.
    /// Shares use 18 decimals, amounts use raw stake-token units. Cost rounds upward to avoid free dust buys.
    function quote(uint256 roundId, Side side, uint256 shares) public view returns (uint256) {
        Round memory r = _viewRound(roundId);
        if (shares == 0) revert InvalidAmount();
        uint256 sold = side == Side.Up ? r.upSold : r.downSold;
        if (shares > r.sharesPerSide - sold) revert InsufficientReserve();
        uint256 total = r.upSold + r.downSold;
        uint256 beforeChance = Math.mulDiv(sold, SHARE_SCALE, total);
        uint256 afterChance = Math.mulDiv(sold + shares, SHARE_SCALE, total + shares);
        return Math.mulDiv(
            shares, i_payout * (beforeChance + afterChance), 2 * SHARE_SCALE * SHARE_SCALE, Math.Rounding.Ceil
        );
    }

    /// @notice Pay exactly the current quote; maxCost protects a pending exact-share order.
    /// The cutoff is the deadline. Requote and send a fresh transaction if the cost changes.
    function buy(uint256 roundId, Side side, uint256 shares, uint256 maxCost) external payable nonReentrant {
        if (phase(roundId) != Phase.Trading) revert OutsideTrading();
        if (msg.sender == owner()) revert PayerCannotBuy();
        uint256 cost = quote(roundId, side, shares);
        if (cost > maxCost) revert SlippageExceeded();
        Round storage r = _materialize(roundId);
        Position storage p = s_positions[roundId][msg.sender];
        if (p.bought + cost > r.stakeCap) revert StakeCapExceeded();
        r.refundLiability -= p.paid;
        uint256 oldPayout = Math.mulDiv(side == Side.Up ? p.up : p.down, i_payout, SHARE_SCALE);
        p.bought += cost;
        p.paid = p.bought > p.proceeds ? p.bought - p.proceeds : 0;
        if (side == Side.Up) {
            p.up += shares;
            r.upSold += shares;
        } else {
            p.down += shares;
            r.downSold += shares;
        }
        uint256 newPayout = Math.mulDiv(side == Side.Up ? p.up : p.down, i_payout, SHARE_SCALE);
        if (side == Side.Up) r.upLiability += newPayout - oldPayout;
        else r.downLiability += newPayout - oldPayout;
        r.refundLiability += p.paid;
        r.collateral += cost;
        reservedBalance += cost;
        _checkBacking(r);
        _takeStake(cost);
        emit Bought(roundId, msg.sender, side, shares, cost);
    }

    /// @notice Stake-token proceeds for exact shares. A sell rounds down to raw stake-token units.
    function quoteSell(uint256 roundId, Side side, uint256 shares) public view returns (uint256) {
        Round memory r = _viewRound(roundId);
        if (shares == 0) revert InvalidAmount();
        uint256 sold = side == Side.Up ? r.upSold : r.downSold;
        uint256 lock = r.sharesPerSide / 10;
        if (shares > sold - lock) revert InsufficientShares();
        uint256 total = r.upSold + r.downSold;
        uint256 beforeChance = Math.mulDiv(sold, SHARE_SCALE, total);
        uint256 afterChance = Math.mulDiv(sold - shares, SHARE_SCALE, total - shares);
        return Math.mulDiv(shares, i_payout * (beforeChance + afterChance), 2 * SHARE_SCALE * SHARE_SCALE);
    }

    function sell(uint256 roundId, Side side, uint256 shares, uint256 minProceeds)
        external
        nonReentrant
        returns (uint256 proceeds)
    {
        if (phase(roundId) != Phase.Trading) revert OutsideTrading();
        Position storage p = s_positions[roundId][msg.sender];
        if (shares > (side == Side.Up ? p.up : p.down)) revert InsufficientShares();
        proceeds = quoteSell(roundId, side, shares);
        if (proceeds < minProceeds) revert SlippageExceeded();
        Round storage r = _materialize(roundId);
        r.refundLiability -= p.paid;
        uint256 oldPayout = Math.mulDiv(side == Side.Up ? p.up : p.down, i_payout, SHARE_SCALE);
        p.proceeds += proceeds;
        p.paid = p.bought > p.proceeds ? p.bought - p.proceeds : 0;
        if (side == Side.Up) {
            p.up -= shares;
            r.upSold -= shares;
        } else {
            p.down -= shares;
            r.downSold -= shares;
        }
        uint256 newPayout = Math.mulDiv(side == Side.Up ? p.up : p.down, i_payout, SHARE_SCALE);
        if (side == Side.Up) r.upLiability -= oldPayout - newPayout;
        else r.downLiability -= oldPayout - newPayout;
        r.refundLiability += p.paid;
        if (proceeds > r.collateral) revert InsufficientReserve();
        r.collateral -= proceeds;
        reservedBalance -= proceeds;
        _checkBacking(r);
        emit Sold(roundId, msg.sender, side, shares, proceeds);
        _sendStake(msg.sender, proceeds);
    }

    /// @notice Anyone must capture at the scheduled boundary timestamp. A late price is never substituted.
    function captureBoundary(uint256 roundId) external nonReentrant {
        Round storage r = _materialize(roundId);
        if (r.result != Result.None) revert AlreadySettled();
        bool start = block.timestamp == r.cutoff;
        if (!start && block.timestamp != r.windowEnd) revert OutsideBoundary();
        if ((start ? r.startBlock : r.endBlock) != 0) return;
        BasePoolReader.Reading memory reading = r.reader.capture();
        if (reading.timestamp != block.timestamp) revert NoValidReading();
        if (start) r.startBlock = reading.blockNumber;
        else r.endBlock = reading.blockNumber;
        emit BoundaryCaptured(roundId, start, reading.blockNumber);
    }

    function settle(uint256 roundId) external nonReentrant {
        Round storage r = _materialize(roundId);
        if (block.timestamp < r.windowEnd) revert TooEarlyToSettle();
        if (r.result != Result.None) revert AlreadySettled();
        if (r.startBlock == 0 || r.endBlock == 0) revert NoValidReading();
        BasePoolReader.Reading memory start = r.reader.read(r.startBlock);
        BasePoolReader.Reading memory end = r.reader.read(r.endBlock);
        if (start.timestamp != r.cutoff || end.timestamp != r.windowEnd) revert NoValidReading();
        r.startReading = start;
        r.endReading = end;
        r.result = end.price > start.price ? Result.Up : end.price < start.price ? Result.Down : Result.Tie;
        uint256 owed =
            r.result == Result.Tie ? r.refundLiability : r.result == Result.Up ? r.upLiability : r.downLiability;
        uint256 surplus = r.collateral - owed;
        r.collateral = owed;
        reservedBalance -= surplus;
        fundingBalance += surplus;
        emit Settled(roundId, r.result, start.price, end.price);
    }

    function claimable(uint256 roundId, address player) public view returns (uint256) {
        Round memory r = _viewRound(roundId);
        Position storage p = s_positions[roundId][player];
        if (p.claimed || r.result == Result.None) return 0;
        if (r.result == Result.Tie) return p.paid;
        return Math.mulDiv(r.result == Result.Up ? p.up : p.down, i_payout, SHARE_SCALE);
    }

    function claim(uint256 roundId) external nonReentrant returns (uint256 amount) {
        if (_viewRound(roundId).result == Result.None) revert NotSettled();
        amount = claimable(roundId, msg.sender);
        if (amount == 0) return 0;
        s_positions[roundId][msg.sender].claimed = true;
        s_rounds[roundId].collateral -= amount;
        reservedBalance -= amount;
        emit Claimed(roundId, msg.sender, amount);
        _sendStake(msg.sender, amount);
    }

    /// @notice Withdraw only uncommitted funding and surplus released by settlement.
    function withdrawLiquidity(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > fundingBalance) revert InsufficientFunding();
        fundingBalance -= amount;
        emit LiquidityWithdrawn(msg.sender, amount);
        _sendStake(msg.sender, amount);
    }

    function _checkBacking(Round storage r) private view {
        if (r.collateral < r.upLiability || r.collateral < r.downLiability || r.collateral < r.refundLiability) {
            revert InsufficientReserve();
        }
    }

    function _validateSettings(CampaignSettings memory settings) private view {
        if (
            settings.seed < i_payout || settings.seed > MAX_SEED || settings.stakeCap == 0
                || settings.stakeCap > MAX_STAKE_CAP || settings.tradingSeconds < 5 || settings.tradingSeconds > 30
                || settings.windowSeconds == 0 || settings.windowSeconds > 30
                || settings.tradingSeconds % BLOCK_INTERVAL != 0 || settings.windowSeconds % BLOCK_INTERVAL != 0
                || address(settings.reader).code.length == 0
        ) revert InvalidConfiguration();
    }

    function _scheduleAtTime(uint256 timestamp) private view returns (uint256 index) {
        uint256 high = s_schedule.length;
        while (index + 1 < high) {
            uint256 mid = (index + high) / 2;
            if (s_schedule[mid].start <= timestamp) index = mid;
            else high = mid;
        }
    }

    function _scheduledRound(uint256 roundId) private view returns (Round memory r) {
        if (roundId == 0 || !s_seeded) revert UnknownRound();
        uint256 index = 0;
        uint256 high = s_schedule.length;
        while (index + 1 < high) {
            uint256 mid = (index + high) / 2;
            if (s_schedule[mid].firstRound <= roundId) index = mid;
            else high = mid;
        }
        Schedule storage schedule = s_schedule[index];
        CampaignSettings storage settings = schedule.settings;
        // Bound first, so arbitrary ids cannot overflow time arithmetic.
        uint256 offset = roundId - schedule.firstRound;
        if (offset > (settings.endTime - schedule.start) / settings.tradingSeconds) revert UnknownRound();
        uint256 start = schedule.start + offset * settings.tradingSeconds;
        if (start >= settings.endTime || start > block.timestamp || (stopped && start >= stopAfter)) {
            revert UnknownRound();
        }
        r.reader = settings.reader;
        r.cutoff = start + settings.tradingSeconds;
        r.windowEnd = r.cutoff + settings.windowSeconds;
        r.stakeCap = settings.stakeCap;
        r.seededLiquidity = settings.seed;
        r.sharesPerSide = Math.mulDiv(settings.seed, SHARE_SCALE, i_payout);
        r.upSold = r.sharesPerSide / 10;
        r.downSold = r.upSold;
    }

    function _viewRound(uint256 roundId) private view returns (Round memory) {
        if (s_rounds[roundId].seededLiquidity != 0) return s_rounds[roundId];
        return _scheduledRound(roundId);
    }

    function _materialize(uint256 roundId) private returns (Round storage r) {
        r = s_rounds[roundId];
        if (r.seededLiquidity != 0) return r;
        Round memory scheduled = _scheduledRound(roundId);
        uint256 seed = scheduled.seededLiquidity;
        if (seed > fundingBalance) revert InsufficientFunding();
        fundingBalance -= seed;
        reservedBalance += seed;
        scheduled.collateral = seed;
        s_rounds[roundId] = scheduled;
        emit RoundSeeded(roundId, seed, scheduled.cutoff, scheduled.windowEnd, scheduled.stakeCap);
    }
}

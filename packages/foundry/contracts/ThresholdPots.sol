// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "./readings/BasePoolReader.sol";
import { MarketCapReader } from "./readings/MarketCapReader.sol";

/// @notice ETH threshold Pots on a lazy Campaign schedule, settled from pinned TWAP Readings.
contract ThresholdPots is Ownable, ReentrancyGuard {
    enum Side {
        Yes,
        No
    }
    enum Metric {
        Price,
        MarketCap
    }
    enum Result {
        None,
        Yes,
        No,
        Tie,
        Unmatched
    }
    enum Phase {
        Trading,
        Window,
        AwaitingSettlement,
        Settled
    }

    struct Position {
        uint256 yes;
        uint256 no;
        uint256 paid; // Player stakes only; automatic Opening stake does not consume the cap.
        bool claimed;
    }

    struct CampaignSettings {
        uint256 openingStake; // Per side, in wei.
        uint256 stakeCap;
        uint256 threshold; // Fixed rule; Reading units (1e36 quote tokens).
        uint32 tradingSeconds;
        uint32 windowSeconds;
        uint64 endTime; // Exclusive bound on new starts; the final Round finishes in full.
        Metric metric;
        BasePoolReader reader;
        MarketCapReader marketCapReader;
    }

    struct Round {
        BasePoolReader reader;
        MarketCapReader marketCapReader;
        Metric metric;
        uint256 threshold;
        uint256 cutoff;
        uint256 windowEnd;
        uint256 stakeCap;
        uint256 openingStake;
        address payer;
        uint256 yesTotal;
        uint256 noTotal;
        uint256 pot; // Original final Pot after settlement; never decremented by claims.
        uint256 collateral; // Unclaimed escrow, including unresolved rounding reserve.
        uint256 endBlock;
        uint256 remainingWinningStake;
        uint256 dustReleased;
        Result result;
        BasePoolReader.Reading endReading;
        uint256 totalSupply;
        uint256 endValue;
        bool materialized;
    }

    struct Schedule {
        uint256 firstRound;
        uint256 start;
        CampaignSettings settings;
    }

    error InvalidConfiguration();
    error CampaignStopped();
    error RoundAlreadySeeded();
    error UnknownRound();
    error InsufficientFunding();
    error InvalidAmount();
    error OutsideTrading();
    error StakeCapExceeded();
    error OutsideBoundary();
    error AlreadySettled();
    error TooEarlyToSettle();
    error NoValidReading();
    error NotSettled();
    error TransferFailed();

    uint256 public constant BLOCK_INTERVAL = 2;
    uint256 public constant MAX_OPENING_STAKE = 1e30;
    uint256 public constant MAX_STAKE_CAP = 1e30;
    BasePoolReader public immutable i_reader;
    uint256 public fundingBalance;
    uint256 public reservedBalance;
    uint256 public totalDustCredit;
    mapping(address => uint256) public dustCredit;
    mapping(uint256 => Round) private s_rounds;
    mapping(uint256 => mapping(address => Position)) private s_positions;
    Schedule[] private s_schedule;
    bool private s_seeded;
    bool public stopped;
    uint256 public stopAfter;

    event Funded(address indexed payer, uint256 amount);
    event RoundSeeded(
        uint256 indexed roundId, address indexed payer, uint256 openingStake, uint256 cutoff, uint256 windowEnd
    );
    event Staked(uint256 indexed roundId, address indexed player, Side side, uint256 amount);
    event BoundaryCaptured(uint256 indexed roundId, uint256 blockNumber);
    event Settled(uint256 indexed roundId, Result result, uint256 endValue, uint256 threshold);
    event Claimed(uint256 indexed roundId, address indexed player, uint256 amount);
    event DustCredited(uint256 indexed roundId, address indexed payer, uint256 amount);
    event DustWithdrawn(address indexed payer, uint256 amount);
    event FundingWithdrawn(address indexed payer, uint256 amount);
    event SettingsScheduled(uint256 indexed firstRound, uint256 start, CampaignSettings settings);
    event CampaignStopScheduled(uint256 cutoff);

    constructor(address payer, BasePoolReader reader) Ownable(payer) {
        if (address(reader).code.length == 0) revert InvalidConfiguration();
        i_reader = reader;
    }

    function fund() external payable onlyOwner {
        if (msg.value == 0) revert InvalidAmount();
        fundingBalance += msg.value;
        emit Funded(msg.sender, msg.value);
    }

    function seedRound(CampaignSettings calldata settings) external onlyOwner {
        if (stopped) revert CampaignStopped();
        if (s_seeded) revert RoundAlreadySeeded();
        _validateSettings(settings);
        if (settings.endTime <= block.timestamp) revert InvalidConfiguration();
        s_seeded = true;
        s_schedule.push(Schedule(1, block.timestamp, settings));
        _materialize(1);
    }

    function currentRound() public view returns (uint256) {
        if (!s_seeded) return 0;
        Schedule storage schedule = s_schedule[_scheduleAtTime(block.timestamp)];
        uint256 offset = (block.timestamp - schedule.start) / schedule.settings.tradingSeconds;
        uint256 start = schedule.start + offset * schedule.settings.tradingSeconds;
        if (start >= schedule.settings.endTime || (stopped && start >= stopAfter)) return 0;
        return schedule.firstRound + offset;
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

    function stake(uint256 roundId, Side side) external payable nonReentrant {
        if (phase(roundId) != Phase.Trading) revert OutsideTrading();
        if (msg.value == 0) revert InvalidAmount();
        Round storage r = _materialize(roundId);
        Position storage p = s_positions[roundId][msg.sender];
        if (msg.value > r.stakeCap - p.paid) revert StakeCapExceeded();
        p.paid += msg.value;
        if (side == Side.Yes) {
            p.yes += msg.value;
            r.yesTotal += msg.value;
        } else {
            p.no += msg.value;
            r.noTotal += msg.value;
        }
        r.pot += msg.value;
        r.collateral += msg.value;
        reservedBalance += msg.value;
        emit Staked(roundId, msg.sender, side, msg.value);
    }

    /// @notice Schedule new settings at the current Trading cutoff; existing Rounds stay pinned.
    function setCampaignSettings(CampaignSettings calldata settings) external onlyOwner {
        if (stopped) revert CampaignStopped();
        uint256 active = currentRound();
        if (active == 0) revert InvalidConfiguration();
        Round memory current = _viewRound(active);
        _validateSettings(settings);
        if (settings.endTime <= current.cutoff) revert InvalidConfiguration();
        Schedule memory next = Schedule(active + 1, current.cutoff, settings);
        uint256 last = s_schedule.length - 1;
        if (s_schedule[last].firstRound == active + 1) s_schedule[last] = next;
        else s_schedule.push(next);
        emit SettingsScheduled(active + 1, current.cutoff, settings);
    }

    /// @notice Irreversibly stop new starts after the currently scheduled Trading Round.
    function stopCampaign() external onlyOwner {
        if (stopped) revert CampaignStopped();
        uint256 active = currentRound();
        stopAfter = active == 0 ? block.timestamp : _viewRound(active).cutoff;
        stopped = true;
        emit CampaignStopScheduled(stopAfter);
    }

    /// @notice Capture the fixed threshold's end Reading at its exact scheduled endpoint.
    function captureBoundary(uint256 roundId) external nonReentrant {
        Round storage r = _materialize(roundId);
        if (r.result != Result.None) revert AlreadySettled();
        if (block.timestamp != r.windowEnd) revert OutsideBoundary();
        if (r.endBlock != 0) return;
        BasePoolReader.Reading memory reading = r.reader.capture();
        if (reading.timestamp != r.windowEnd) revert NoValidReading();
        r.endBlock = reading.blockNumber;
        emit BoundaryCaptured(roundId, reading.blockNumber);
    }

    function settle(uint256 roundId) external nonReentrant {
        Round storage r = _materialize(roundId);
        if (r.result != Result.None) revert AlreadySettled();
        if (block.timestamp < r.windowEnd) revert TooEarlyToSettle();
        if (r.yesTotal == 0 || r.noTotal == 0) {
            r.result = Result.Unmatched;
        } else {
            if (r.endBlock == 0) revert NoValidReading();
            if (r.metric == Metric.Price) {
                r.endReading = r.reader.read(r.endBlock);
                r.endValue = r.endReading.price;
            } else {
                MarketCapReader.MarketCapReading memory reading = r.marketCapReader.readMarketCap(r.endBlock);
                r.endReading = reading.reading;
                r.totalSupply = reading.totalSupply;
                r.endValue = reading.marketCap;
            }
            if (r.endReading.timestamp != r.windowEnd) revert NoValidReading();
            r.result = r.endValue > r.threshold ? Result.Yes : r.endValue < r.threshold ? Result.No : Result.Tie;
            if (r.result == Result.Yes) r.remainingWinningStake = r.yesTotal;
            else if (r.result == Result.No) r.remainingWinningStake = r.noTotal;
        }
        emit Settled(roundId, r.result, r.endValue, r.threshold);
    }

    function claimable(uint256 roundId, address player) public view returns (uint256) {
        Round memory r = _viewRound(roundId);
        Position storage p = s_positions[roundId][player];
        if (p.claimed || r.result == Result.None) return 0;
        if (r.result == Result.Tie || r.result == Result.Unmatched) return p.yes + p.no;
        return
            Math.mulDiv(r.result == Result.Yes ? p.yes : p.no, r.pot, r.result == Result.Yes ? r.yesTotal : r.noTotal);
    }

    function claim(uint256 roundId) external nonReentrant returns (uint256 amount) {
        Round storage r = s_rounds[roundId];
        if (_viewRound(roundId).result == Result.None) revert NotSettled();
        Position storage p = s_positions[roundId][msg.sender];
        if (p.claimed) return 0;
        amount = claimable(roundId, msg.sender);
        p.claimed = true;
        r.collateral -= amount;
        reservedBalance -= amount;
        if (r.result == Result.Yes || r.result == Result.No) {
            uint256 winningStake = r.result == Result.Yes ? p.yes : p.no;
            if (winningStake != 0) {
                r.remainingWinningStake -= winningStake;
                if (r.remainingWinningStake == 0) {
                    // Only after every winner is consumed is the residual proven to be dust.
                    uint256 dust = r.collateral;
                    r.collateral = 0;
                    reservedBalance -= dust;
                    r.dustReleased = dust;
                    dustCredit[r.payer] += dust;
                    totalDustCredit += dust;
                    emit DustCredited(roundId, r.payer, dust);
                }
            }
        }
        emit Claimed(roundId, msg.sender, amount);
        if (amount != 0) {
            (bool success,) = msg.sender.call{ value: amount }("");
            if (!success) revert TransferFailed();
        }
    }

    /// @notice Withdraw only prefunding not committed to a materialized Round.
    function withdrawFunding(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (amount > fundingBalance) revert InsufficientFunding();
        fundingBalance -= amount;
        emit FundingWithdrawn(msg.sender, amount);
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    /// @notice Dust follows the original Round payer, independently of later ownership changes.
    function withdrawDust() external nonReentrant returns (uint256 amount) {
        amount = dustCredit[msg.sender];
        if (amount == 0) return 0;
        dustCredit[msg.sender] = 0;
        totalDustCredit -= amount;
        emit DustWithdrawn(msg.sender, amount);
        (bool success,) = msg.sender.call{ value: amount }("");
        if (!success) revert TransferFailed();
    }

    function _validateSettings(CampaignSettings memory settings) private view {
        if (
            settings.openingStake > MAX_OPENING_STAKE || settings.stakeCap == 0 || settings.stakeCap > MAX_STAKE_CAP
                || settings.threshold == 0 || settings.tradingSeconds < 5 || settings.tradingSeconds > 30
                || settings.windowSeconds == 0 || settings.windowSeconds > 30
                || settings.tradingSeconds % BLOCK_INTERVAL != 0 || settings.windowSeconds % BLOCK_INTERVAL != 0
                || address(settings.reader).code.length == 0
        ) revert InvalidConfiguration();
        if (settings.metric == Metric.MarketCap) {
            if (address(settings.marketCapReader).code.length == 0) revert InvalidConfiguration();
            if (
                settings.marketCapReader.i_supplyMode() == MarketCapReader.SupplyMode.Unsupported
                    || address(settings.marketCapReader.i_priceReader()) != address(settings.reader)
            ) revert InvalidConfiguration();
        }
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
        uint256 offset = roundId - schedule.firstRound;
        if (offset > (settings.endTime - schedule.start) / settings.tradingSeconds) revert UnknownRound();
        uint256 start = schedule.start + offset * settings.tradingSeconds;
        if (start >= settings.endTime || start > block.timestamp || (stopped && start >= stopAfter)) {
            revert UnknownRound();
        }
        r.reader = settings.reader;
        r.marketCapReader = settings.marketCapReader;
        r.metric = settings.metric;
        r.threshold = settings.threshold;
        r.cutoff = start + settings.tradingSeconds;
        r.windowEnd = r.cutoff + settings.windowSeconds;
        r.stakeCap = settings.stakeCap;
        r.openingStake = settings.openingStake;
        r.payer = owner();
        r.yesTotal = settings.openingStake;
        r.noTotal = settings.openingStake;
        r.pot = 2 * settings.openingStake;
    }

    function _viewRound(uint256 roundId) private view returns (Round memory) {
        if (s_rounds[roundId].materialized) return s_rounds[roundId];
        return _scheduledRound(roundId);
    }

    function _materialize(uint256 roundId) private returns (Round storage r) {
        r = s_rounds[roundId];
        if (r.materialized) return r;
        Round memory scheduled = _scheduledRound(roundId);
        if (scheduled.pot > fundingBalance) revert InsufficientFunding();
        fundingBalance -= scheduled.pot;
        reservedBalance += scheduled.pot;
        scheduled.collateral = scheduled.pot;
        scheduled.materialized = true;
        s_rounds[roundId] = scheduled;
        Position storage payerPosition = s_positions[roundId][scheduled.payer];
        payerPosition.yes = scheduled.openingStake;
        payerPosition.no = scheduled.openingStake;
        emit RoundSeeded(roundId, scheduled.payer, scheduled.openingStake, scheduled.cutoff, scheduled.windowEnd);
    }
}

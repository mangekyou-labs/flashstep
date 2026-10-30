// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { UpDownRounds } from "../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../contracts/readings/MarketCapReader.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { StakeCapRule } from "./lib/StakeCapRule.sol";

/// @dev The identity calls of a Uniswap V3 pool that the vetting reads.
interface IV3PoolIdentity {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

interface IV3FactoryRegistry {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address);
}

/// @notice Deploys both Round contracts from the payer's own wallet, so the payer is the owner and the
/// developer holds nothing (ADR 0004). The signer is whatever the CLI supplies (`--account` or `--ledger`);
/// the script never takes a key. The configured `payer` must equal that signer or the run reverts.
/// @dev Phase one is `run()` (deploy). Phase two, `fundAndSeed()`, is run by `scripts-js/payerDeploy.js`
/// only after a human has approved the priced funding table. See docs/implementation/payer-deploy.md.
contract DeployPayerCampaign is Script {
    using SafeERC20 for IERC20;

    error SignerIsNotPayer(address signer, address payer);
    error PayerBalanceTooLow(uint256 required, uint256 balance);
    error NotOwnedBySigner(address target, address owner, address signer);
    error InvalidConfig(ConfigField field);
    error NotAContract(Vetted what, address target);
    error UnsupportedChain(uint256 chainId);
    error WrongFactory(address actual, address expected);
    error PoolTokensMismatch(address baseToken);
    error PoolFeeMismatch(uint24 actual, uint24 expected);
    error PoolNotRegistered(address registered);
    error StakeTokenIsNotThePoolQuote(address stakeToken);
    error StakeCapAboveRule(Campaign campaign, uint256 stakeCap, uint256 maxByRule);

    enum Campaign {
        UpDown,
        Threshold
    }

    /// @dev The addresses whose code the vetting checks.
    enum Vetted {
        Pool,
        BaseToken,
        Factory,
        StakeToken
    }

    /// @dev The config settings that can be invalid for a reason other than a bad address.
    enum ConfigField {
        ThresholdMetric,
        ThresholdSupplyMode,
        UpDownDuration,
        ThresholdDuration
    }

    /// @dev The Uniswap V3 factories the pool must come from. Fixed in code on live chains, so a config file
    /// cannot point the vetting at a look-alike factory. Chain 31337 reads the factory from the config.
    address internal constant BASE_V3_FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address internal constant BASE_SEPOLIA_V3_FACTORY = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    struct UpDownConfig {
        uint256 payout;
        uint256 seed;
        uint256 stakeCap;
        uint32 tradingSeconds;
        uint32 windowSeconds;
        uint64 durationSeconds; // 0 = open-ended
        uint256 funding;
    }

    struct ThresholdConfig {
        ThresholdPots.Metric metric;
        uint256 threshold;
        uint256 openingStake;
        uint256 stakeCap;
        uint32 tradingSeconds;
        uint32 windowSeconds;
        uint64 durationSeconds; // 0 = open-ended
        uint256 funding;
        MarketCapReader.SupplyMode supplyMode;
        uint256 fixedSupply;
    }

    struct Config {
        address payer;
        address stakeToken; // address(0) = ETH
        address pool;
        address baseToken;
        uint24 poolFee;
        address poolFactory; // honoured on chain 31337 only
        uint32 lookbackSeconds;
        bool allowStakeCapAboveRule;
        UpDownConfig updown;
        ThresholdConfig threshold;
    }

    /// @notice Vet the configured pool and stake token without broadcasting. The driver runs this first and
    /// shows the result before asking for a yes; `run()` runs it again so a bad address can never be deployed.
    function preflight() external view {
        _vet(_loadConfig());
    }

    /// @notice Phase one: deploy the readers and both Round contracts as the payer.
    function run() external {
        Config memory cfg = _loadConfig();
        _vet(cfg);
        _beginBroadcast();
        (, address signer,) = vm.readCallers();
        if (signer != cfg.payer) revert SignerIsNotPayer(signer, cfg.payer);

        BasePoolReader priceReader = new BasePoolReader(cfg.pool, cfg.baseToken, cfg.lookbackSeconds);
        UpDownRounds upDown = new UpDownRounds(cfg.payer, priceReader, cfg.stakeToken, cfg.updown.payout);
        ThresholdPots threshold = new ThresholdPots(cfg.payer, priceReader, cfg.stakeToken);
        MarketCapReader marketCapReader;
        if (cfg.threshold.metric == ThresholdPots.Metric.MarketCap) {
            marketCapReader = new MarketCapReader(priceReader, cfg.threshold.supplyMode, cfg.threshold.fixedSupply);
        }
        vm.stopBroadcast();

        string memory out = "payerDeploy";
        vm.serializeUint(out, "chainId", block.chainid);
        vm.serializeAddress(out, "payer", cfg.payer);
        vm.serializeAddress(out, "stakeToken", cfg.stakeToken);
        vm.serializeAddress(out, "pool", cfg.pool);
        vm.serializeAddress(out, "priceReader", address(priceReader));
        vm.serializeAddress(out, "marketCapReader", address(marketCapReader));
        vm.serializeAddress(out, "upDown", address(upDown));
        string memory json = vm.serializeAddress(out, "threshold", address(threshold));
        vm.writeJson(json, _outPath());
        console.log("UpDownRounds  ", address(upDown));
        console.log("ThresholdPots ", address(threshold));
    }

    /// @notice Phase two: fund both contracts and start both Campaigns. Run only after a human approved the
    /// priced funding table (scripts-js/payerDeploy.js). Spends the payer's stake tokens, exact amounts only.
    function fundAndSeed() external {
        Config memory cfg = _loadConfig();
        string memory deployed = vm.readFile(_outPath());
        UpDownRounds upDown = UpDownRounds(vm.parseJsonAddress(deployed, ".upDown"));
        ThresholdPots threshold = ThresholdPots(vm.parseJsonAddress(deployed, ".threshold"));
        address marketCapReader = vm.parseJsonAddress(deployed, ".marketCapReader");

        _beginBroadcast();
        (, address signer,) = vm.readCallers();
        if (signer != cfg.payer) revert SignerIsNotPayer(signer, cfg.payer);
        if (upDown.owner() != signer) revert NotOwnedBySigner(address(upDown), upDown.owner(), signer);
        if (threshold.owner() != signer) revert NotOwnedBySigner(address(threshold), threshold.owner(), signer);

        bool isEth = cfg.stakeToken == address(0);
        uint256 required = cfg.updown.funding + cfg.threshold.funding;
        uint256 held = isEth ? signer.balance : IERC20(cfg.stakeToken).balanceOf(signer);
        if (held < required) revert PayerBalanceTooLow(required, held);

        if (!isEth) {
            IERC20(cfg.stakeToken).forceApprove(address(upDown), cfg.updown.funding);
            IERC20(cfg.stakeToken).forceApprove(address(threshold), cfg.threshold.funding);
        }
        upDown.fund{ value: isEth ? cfg.updown.funding : 0 }(cfg.updown.funding);
        upDown.seedRound(cfg.updown.seed, cfg.updown.stakeCap, cfg.updown.tradingSeconds, cfg.updown.windowSeconds);
        if (cfg.updown.durationSeconds != 0) {
            upDown.setCampaignSettings(
                cfg.updown.seed,
                cfg.updown.stakeCap,
                cfg.updown.tradingSeconds,
                cfg.updown.windowSeconds,
                uint64(block.timestamp + cfg.updown.durationSeconds),
                upDown.i_reader()
            );
        }

        threshold.fund{ value: isEth ? cfg.threshold.funding : 0 }(cfg.threshold.funding);
        threshold.seedRound(
            ThresholdPots.CampaignSettings({
                openingStake: cfg.threshold.openingStake,
                stakeCap: cfg.threshold.stakeCap,
                threshold: cfg.threshold.threshold,
                tradingSeconds: cfg.threshold.tradingSeconds,
                windowSeconds: cfg.threshold.windowSeconds,
                endTime: cfg.threshold.durationSeconds == 0
                    ? type(uint64).max
                    : uint64(block.timestamp + cfg.threshold.durationSeconds),
                metric: cfg.threshold.metric,
                reader: threshold.i_reader(),
                marketCapReader: MarketCapReader(marketCapReader)
            })
        );
        vm.stopBroadcast();
        console.log("Funded and seeded both Campaigns");
    }

    function _expectedFactory(Config memory cfg) internal view returns (address) {
        if (block.chainid == 8453) return BASE_V3_FACTORY;
        if (block.chainid == 84532) return BASE_SEPOLIA_V3_FACTORY;
        if (block.chainid == 31337) return cfg.poolFactory;
        revert UnsupportedChain(block.chainid);
    }

    /// @dev Code and identity checks on every address the Campaigns will trust, before anything is signed.
    function _vet(Config memory cfg) internal view {
        address expectedFactory = _expectedFactory(cfg);
        _requireCode(Vetted.Pool, cfg.pool);
        _requireCode(Vetted.BaseToken, cfg.baseToken);
        _requireCode(Vetted.Factory, expectedFactory);
        if (cfg.stakeToken != address(0)) _requireCode(Vetted.StakeToken, cfg.stakeToken);

        IV3PoolIdentity pool = IV3PoolIdentity(cfg.pool);
        address actualFactory = pool.factory();
        if (actualFactory != expectedFactory) revert WrongFactory(actualFactory, expectedFactory);
        address token0 = pool.token0();
        address token1 = pool.token1();
        if (cfg.baseToken != token0 && cfg.baseToken != token1) revert PoolTokensMismatch(cfg.baseToken);
        uint24 actualFee = pool.fee();
        if (actualFee != cfg.poolFee) revert PoolFeeMismatch(actualFee, cfg.poolFee);
        address registered = IV3FactoryRegistry(expectedFactory).getPool(token0, token1, actualFee);
        if (registered != cfg.pool) revert PoolNotRegistered(registered);

        address quoteToken = token0 == cfg.baseToken ? token1 : token0;
        _checkStakeToken(cfg, quoteToken);
        if (!cfg.allowStakeCapAboveRule) _checkStakeCapRule(cfg, quoteToken, actualFee);
    }

    /// @dev The stake token must be the pool's quote token, so the Readings and the Stake cap are in the same unit.
    /// ETH is the one exception: the rule cannot measure it against an ERC-20 pool, so it needs the payer's explicit
    /// `allowStakeCapAboveRule`. This check is not skipped by that flag for any ERC-20.
    function _checkStakeToken(Config memory cfg, address quoteToken) internal pure {
        if (cfg.stakeToken == address(0) && cfg.allowStakeCapAboveRule) return;
        if (cfg.stakeToken != quoteToken) revert StakeTokenIsNotThePoolQuote(cfg.stakeToken);
    }

    /// @dev The Stake cap rule of thumb (docs/implementation/payer-deploy.md). Depth is the quote token the pool
    /// holds. Only this revert is bypassed by `allowStakeCapAboveRule`.
    function _checkStakeCapRule(Config memory cfg, address quoteToken, uint24 fee) internal view {
        uint256 depth = IERC20(quoteToken).balanceOf(cfg.pool);
        _requireCapUnderRule(Campaign.UpDown, cfg.updown.stakeCap, cfg.updown.windowSeconds, cfg, depth, fee);
        _requireCapUnderRule(Campaign.Threshold, cfg.threshold.stakeCap, cfg.threshold.windowSeconds, cfg, depth, fee);
    }

    function _requireCapUnderRule(
        Campaign campaign,
        uint256 stakeCap,
        uint32 windowSeconds,
        Config memory cfg,
        uint256 depth,
        uint24 fee
    ) private pure {
        uint256 maxByRule = StakeCapRule.maxStakeCap(depth, windowSeconds, cfg.lookbackSeconds, fee);
        if (stakeCap > maxByRule) revert StakeCapAboveRule(campaign, stakeCap, maxByRule);
    }

    function _requireCode(Vetted what, address target) private view {
        if (target.code.length == 0) revert NotAContract(what, target);
    }

    /// @dev Overridden only by tests, to sign as a chosen payer. The CLI signer is used in production.
    function _beginBroadcast() internal virtual {
        vm.startBroadcast();
    }

    /// @dev Where the deployed addresses are written and read back. Tests override it to stay isolated.
    function _outPath() internal view virtual returns (string memory) {
        string memory fallbackPath =
            string.concat(vm.projectRoot(), "/deployments/payer-", vm.toString(block.chainid), ".json");
        return vm.envOr("PAYER_DEPLOY_OUT", fallbackPath);
    }

    /// @dev The Campaign settings file (no secrets). Tests override it to stay isolated.
    function _configPath() internal view virtual returns (string memory) {
        return vm.envString("PAYER_CONFIG");
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        string memory json = vm.readFile(_configPath());
        cfg.payer = vm.parseJsonAddress(json, ".payer");
        cfg.stakeToken = vm.parseJsonAddress(json, ".stakeToken");
        cfg.pool = vm.parseJsonAddress(json, ".pool");
        cfg.baseToken = vm.parseJsonAddress(json, ".baseToken");
        cfg.poolFee = uint24(vm.parseJsonUint(json, ".poolFee"));
        cfg.poolFactory =
            vm.keyExistsJson(json, ".poolFactory") ? vm.parseJsonAddress(json, ".poolFactory") : address(0);
        cfg.lookbackSeconds = uint32(vm.parseJsonUint(json, ".lookbackSeconds"));
        cfg.allowStakeCapAboveRule = vm.parseJsonBool(json, ".allowStakeCapAboveRule");

        cfg.updown.payout = vm.parseJsonUint(json, ".updown.payout");
        cfg.updown.seed = vm.parseJsonUint(json, ".updown.seed");
        cfg.updown.stakeCap = vm.parseJsonUint(json, ".updown.stakeCap");
        cfg.updown.tradingSeconds = uint32(vm.parseJsonUint(json, ".updown.tradingSeconds"));
        cfg.updown.windowSeconds = uint32(vm.parseJsonUint(json, ".updown.windowSeconds"));
        cfg.updown.durationSeconds = uint64(vm.parseJsonUint(json, ".updown.durationSeconds"));
        cfg.updown.funding = vm.parseJsonUint(json, ".updown.funding");

        string memory metric = vm.parseJsonString(json, ".threshold.metric");
        cfg.threshold.metric = _eq(metric, "MarketCap") ? ThresholdPots.Metric.MarketCap : ThresholdPots.Metric.Price;
        if (!_eq(metric, "MarketCap") && !_eq(metric, "Price")) revert InvalidConfig(ConfigField.ThresholdMetric);
        cfg.threshold.threshold = vm.parseJsonUint(json, ".threshold.threshold");
        cfg.threshold.openingStake = vm.parseJsonUint(json, ".threshold.openingStake");
        cfg.threshold.stakeCap = vm.parseJsonUint(json, ".threshold.stakeCap");
        cfg.threshold.tradingSeconds = uint32(vm.parseJsonUint(json, ".threshold.tradingSeconds"));
        cfg.threshold.windowSeconds = uint32(vm.parseJsonUint(json, ".threshold.windowSeconds"));
        cfg.threshold.durationSeconds = uint64(vm.parseJsonUint(json, ".threshold.durationSeconds"));
        cfg.threshold.funding = vm.parseJsonUint(json, ".threshold.funding");
        string memory mode = vm.parseJsonString(json, ".threshold.supplyMode");
        if (_eq(mode, "Fixed")) cfg.threshold.supplyMode = MarketCapReader.SupplyMode.Fixed;
        else if (_eq(mode, "Checkpoints")) cfg.threshold.supplyMode = MarketCapReader.SupplyMode.Checkpoints;
        else if (!_eq(mode, "Unsupported")) revert InvalidConfig(ConfigField.ThresholdSupplyMode);
        cfg.threshold.fixedSupply = vm.parseJsonUint(json, ".threshold.fixedSupply");

        // A Campaign that ends before its first Round is over would never settle anything.
        _requireDurationOutlastsTradingPhase(
            ConfigField.UpDownDuration, cfg.updown.durationSeconds, cfg.updown.tradingSeconds
        );
        _requireDurationOutlastsTradingPhase(
            ConfigField.ThresholdDuration, cfg.threshold.durationSeconds, cfg.threshold.tradingSeconds
        );
    }

    function _requireDurationOutlastsTradingPhase(ConfigField field, uint64 durationSeconds, uint32 tradingSeconds)
        private
        pure
    {
        if (durationSeconds != 0 && durationSeconds <= tradingSeconds) revert InvalidConfig(field);
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

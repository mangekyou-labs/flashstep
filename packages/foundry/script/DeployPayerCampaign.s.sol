// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script, console } from "forge-std/Script.sol";
import { UpDownRounds } from "../contracts/UpDownRounds.sol";
import { ThresholdPots } from "../contracts/ThresholdPots.sol";
import { BasePoolReader } from "../contracts/readings/BasePoolReader.sol";
import { MarketCapReader } from "../contracts/readings/MarketCapReader.sol";

/// @notice Deploys both Round contracts from the payer's own wallet, so the payer is the owner and the
/// developer holds nothing (ADR 0004). The signer is whatever the CLI supplies (`--account` or `--ledger`);
/// the script never takes a key. The configured `payer` must equal that signer or the run reverts.
/// @dev Phase one is `run()` (deploy). Phase two, `fundAndSeed()`, is run by `scripts-js/payerDeploy.js`
/// only after a human has approved the priced funding table. See docs/implementation/payer-deploy.md.
contract DeployPayerCampaign is Script {
    error SignerIsNotPayer(address signer, address payer);
    error InvalidConfig(string reason);

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

    /// @notice Phase one: deploy the readers and both Round contracts as the payer.
    function run() external {
        Config memory cfg = _loadConfig();
        _beginBroadcast();
        (, address signer,) = vm.readCallers();
        if (signer != cfg.payer) revert SignerIsNotPayer(signer, cfg.payer);

        BasePoolReader priceReader = new BasePoolReader(cfg.pool, cfg.baseToken, cfg.lookbackSeconds);
        UpDownRounds upDown = new UpDownRounds(cfg.payer, priceReader, cfg.stakeToken, cfg.updown.payout);
        ThresholdPots threshold = new ThresholdPots(cfg.payer, priceReader, cfg.stakeToken);
        vm.stopBroadcast();

        string memory out = "payerDeploy";
        vm.serializeUint(out, "chainId", block.chainid);
        vm.serializeAddress(out, "payer", cfg.payer);
        vm.serializeAddress(out, "stakeToken", cfg.stakeToken);
        vm.serializeAddress(out, "pool", cfg.pool);
        vm.serializeAddress(out, "priceReader", address(priceReader));
        vm.serializeAddress(out, "upDown", address(upDown));
        string memory json = vm.serializeAddress(out, "threshold", address(threshold));
        vm.writeJson(json, _outPath());
        console.log("UpDownRounds  ", address(upDown));
        console.log("ThresholdPots ", address(threshold));
    }

    /// @dev Overridden only by tests, to sign as a chosen payer. The CLI signer is used in production.
    function _beginBroadcast() internal virtual {
        vm.startBroadcast();
    }

    function _outPath() internal view returns (string memory) {
        return vm.envOr("PAYER_DEPLOY_OUT", string.concat(vm.projectRoot(), "/deployments/payer-", vm.toString(block.chainid), ".json"));
    }

    function _loadConfig() internal view returns (Config memory cfg) {
        string memory json = vm.readFile(vm.envString("PAYER_CONFIG"));
        cfg.payer = vm.parseJsonAddress(json, ".payer");
        cfg.stakeToken = vm.parseJsonAddress(json, ".stakeToken");
        cfg.pool = vm.parseJsonAddress(json, ".pool");
        cfg.baseToken = vm.parseJsonAddress(json, ".baseToken");
        cfg.poolFee = uint24(vm.parseJsonUint(json, ".poolFee"));
        cfg.poolFactory = vm.keyExistsJson(json, ".poolFactory") ? vm.parseJsonAddress(json, ".poolFactory") : address(0);
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
        if (!_eq(metric, "MarketCap") && !_eq(metric, "Price")) revert InvalidConfig("threshold.metric");
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
        else if (!_eq(mode, "Unsupported")) revert InvalidConfig("threshold.supplyMode");
        cfg.threshold.fixedSupply = vm.parseJsonUint(json, ".threshold.fixedSupply");
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

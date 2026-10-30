// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { DeployPayerCampaign } from "../../script/DeployPayerCampaign.s.sol";
import { StakeTokenMock } from "../mocks/StakeTokenMock.sol";
import { MockReadingToken } from "../mocks/MockBasePool.sol";
import { MockV3Factory, MockV3Pool } from "../mocks/MockUniswapV3.sol";

/// @notice The script under test, signing as a chosen payer the way `--account` would.
contract SignedAsPayer is DeployPayerCampaign {
    address public immutable signer;
    string private s_configPath;
    string private s_outPath;

    constructor(address signer_, string memory configPath_, string memory outPath_) {
        signer = signer_;
        s_configPath = configPath_;
        s_outPath = outPath_;
    }

    function _configPath() internal view override returns (string memory) {
        return s_configPath;
    }

    function _outPath() internal view override returns (string memory) {
        return s_outPath;
    }

    function _beginBroadcast() internal override {
        vm.startBroadcast(signer);
    }
}

abstract contract PayerDeployFixture is Test {
    // Unique per test, so tests running in parallel never share a config or result file.
    string internal configPath;
    string internal outPath;

    address internal payer = makeAddr("payer");
    address internal developer = makeAddr("developer");

    StakeTokenMock internal quote; // doubles as the stake token: the Stake cap rule needs stake == quote
    MockReadingToken internal base;
    MockV3Factory internal factory;
    MockV3Pool internal pool;
    SignedAsPayer internal script;

    // Pool depth for the Stake cap rule: the quote token held by the pool (18 decimals in this fixture).
    uint256 internal constant POOL_DEPTH = 13_633_808e18;

    uint256 internal upDownSeed = 20e18;
    uint256 internal upDownCap = 5e18;
    uint32 internal upDownTrading = 6;
    uint32 internal upDownWindow = 30;
    uint256 internal upDownDuration = 0;
    uint256 internal upDownFunding = 60e18;

    uint256 internal thresholdValue = 3_000e36;
    uint256 internal openingStake = 1e18;
    uint256 internal thresholdCap = 5e18;
    uint32 internal thresholdTrading = 10;
    uint32 internal thresholdWindow = 30;
    uint256 internal thresholdDuration = 0;
    uint256 internal thresholdFunding = 20e18;
    string internal thresholdMetric = "Price";
    string internal thresholdSupplyMode = "Unsupported";
    uint256 internal thresholdFixedSupply = 0;
    bool internal allowAboveRule = true;

    // What the config file says about the pool; tests change these to feed the vetting bad inputs.
    uint24 internal configuredFee = 500;
    address internal configuredFactory;
    address internal configuredStakeToken;

    function setUp() public virtual {
        vm.warp(1_000);
        vm.roll(500);
        quote = new StakeTokenMock();
        base = new MockReadingToken(18, 100e18);
        factory = new MockV3Factory();
        (address token0, address token1) =
            address(base) < address(quote) ? (address(base), address(quote)) : (address(quote), address(base));
        pool = new MockV3Pool(address(factory), token0, token1, 500);
        pool.write(0);
        factory.setPool(token0, token1, 500, address(pool));
        quote.setBalance(address(pool), POOL_DEPTH);
        quote.setBalance(payer, 1_000e18);
        configuredStakeToken = address(quote);
        configuredFactory = address(factory);
    }

    /// @dev Call at the top of every test, after changing any setting variable. Files are named from the
    /// test suite and test function, so tests running in parallel never share a config or result file.
    function _prepare() internal {
        vm.createDir("cache-payer", true);
        string memory id = string.concat(vm.toString(address(this).codehash), "-", vm.toString(msg.sig));
        configPath = string.concat("cache-payer/config-", id, ".json");
        outPath = string.concat("cache-payer/deploy-", id, ".json");
        if (vm.exists(outPath)) vm.removeFile(outPath);
        script = new SignedAsPayer(payer, configPath, outPath);
        _writeConfig();
    }

    function _writeConfig() private {
        string memory json = string.concat(
            '{"payer":"',
            vm.toString(payer),
            '","stakeToken":"',
            vm.toString(configuredStakeToken),
            '","pool":"',
            vm.toString(address(pool)),
            '","baseToken":"',
            vm.toString(address(base)),
            '","poolFee":',
            vm.toString(uint256(configuredFee)),
            ',"poolFactory":"',
            vm.toString(configuredFactory),
            '","lookbackSeconds":30,"allowStakeCapAboveRule":',
            allowAboveRule ? "true" : "false",
            ",",
            _upDownJson(),
            ",",
            _thresholdJson(),
            "}"
        );
        vm.writeFile(configPath, json);
    }

    function _upDownJson() private view returns (string memory) {
        return string.concat(
            '"updown":{"payout":"1000000000000000000","seed":"',
            vm.toString(upDownSeed),
            '","stakeCap":"',
            vm.toString(upDownCap),
            '","tradingSeconds":',
            vm.toString(uint256(upDownTrading)),
            ',"windowSeconds":',
            vm.toString(uint256(upDownWindow)),
            ',"durationSeconds":',
            vm.toString(upDownDuration),
            ',"funding":"',
            vm.toString(upDownFunding),
            '"}'
        );
    }

    function _thresholdJson() private view returns (string memory) {
        return string.concat(
            '"threshold":{"metric":"',
            thresholdMetric,
            '","threshold":"',
            vm.toString(thresholdValue),
            '","openingStake":"',
            vm.toString(openingStake),
            '","stakeCap":"',
            vm.toString(thresholdCap),
            '","tradingSeconds":',
            vm.toString(uint256(thresholdTrading)),
            ',"windowSeconds":',
            vm.toString(uint256(thresholdWindow)),
            ',"durationSeconds":',
            vm.toString(thresholdDuration),
            ',"funding":"',
            vm.toString(thresholdFunding),
            '","supplyMode":"',
            thresholdSupplyMode,
            '","fixedSupply":"',
            vm.toString(thresholdFixedSupply),
            '"}'
        );
    }
}

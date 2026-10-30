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

    constructor(address signer_) {
        signer = signer_;
    }

    function _beginBroadcast() internal override {
        vm.startBroadcast(signer);
    }
}

abstract contract PayerDeployFixture is Test {
    string internal constant CONFIG_PATH = "cache-payer/test-config.json";
    string internal constant OUT_PATH = "cache-payer/test-deploy.json";

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
    bool internal allowAboveRule = true;

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
        vm.createDir("cache-payer", true);
        vm.setEnv("PAYER_CONFIG", CONFIG_PATH);
        vm.setEnv("PAYER_DEPLOY_OUT", OUT_PATH);
        script = new SignedAsPayer(payer);
        _writeConfig();
    }

    function _writeConfig() internal {
        string memory json = string.concat(
            '{"payer":"',
            vm.toString(payer),
            '","stakeToken":"',
            vm.toString(address(quote)),
            '","pool":"',
            vm.toString(address(pool)),
            '","baseToken":"',
            vm.toString(address(base)),
            '","poolFee":500,"poolFactory":"',
            vm.toString(address(factory)),
            '","lookbackSeconds":30,"allowStakeCapAboveRule":',
            allowAboveRule ? "true" : "false",
            ",",
            _upDownJson(),
            ",",
            _thresholdJson(),
            "}"
        );
        vm.writeFile(CONFIG_PATH, json);
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
            '","supplyMode":"Unsupported","fixedSupply":"0"}'
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { DeployPayerCampaign, IV3PoolIdentity } from "../../script/DeployPayerCampaign.s.sol";
import { StakeCapRule } from "../../script/lib/StakeCapRule.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";

interface IV3Pool {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint8, bool);
    function liquidity() external view returns (uint128);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata)
        external
        returns (int256 amount0, int256 amount1);
}

/// @notice The deploy script's vetting and the Stake cap rule, checked against the real Base WETH/USDC pool
/// at the pinned block (35,000,000, 2025-09-02 05:02:27 UTC). Evidence: docs/implementation/base-pool-volume-evidence.json.
/// Run with BASE_RPC_URL set to an archive-capable Base endpoint; skipped otherwise.
contract StakeCapRuleForkTest is Test {
    address internal constant POOL = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint160 internal constant MAX_SQRT_RATIO_MINUS_ONE =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_341;

    address internal payer = makeAddr("payer");
    string internal configPath = "cache-payer/config-fork.json";
    ConfiguredScript internal script;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
            return;
        }
        vm.createSelectFork(rpc, 35_000_000);
        vm.createDir("cache-payer", true);
        script = new ConfiguredScript(configPath);
    }

    function _writeConfig(uint256 upDownCap, uint256 thresholdCap, bool allow) internal {
        vm.writeFile(
            configPath,
            string.concat(
                '{"payer":"',
                vm.toString(payer),
                '","stakeToken":"',
                vm.toString(USDC),
                '","pool":"',
                vm.toString(POOL),
                '","baseToken":"',
                vm.toString(WETH),
                '","poolFee":500,"lookbackSeconds":30,"allowStakeCapAboveRule":',
                allow ? "true" : "false",
                ',"updown":{"payout":"1000000","seed":"20000000","stakeCap":"',
                vm.toString(upDownCap),
                '","tradingSeconds":6,"windowSeconds":30,"durationSeconds":0,"funding":"60000000"},',
                '"threshold":{"metric":"Price","threshold":"3000000000000000000000000000000000000000",',
                '"openingStake":"1000000","stakeCap":"',
                vm.toString(thresholdCap),
                '","tradingSeconds":10,"windowSeconds":30,"durationSeconds":0,"funding":"20000000",',
                '"supplyMode":"Unsupported","fixedSupply":"0"}}'
            )
        );
    }

    function test_theRealPoolPassesTheVettingAtThePinnedBlock() public {
        assertEq(block.chainid, 8453);
        assertEq(block.timestamp, 1_756_789_347);
        assertEq(IV3PoolIdentity(POOL).factory(), 0x33128a8fC17869897dcE68Ed026d694621f6FDfD, "Uniswap V3 factory");
        assertEq(IV3PoolIdentity(POOL).fee(), 500, "0.05% tier");
        assertEq(IV3PoolIdentity(POOL).token0(), WETH, "token0");
        assertEq(IV3PoolIdentity(POOL).token1(), USDC, "token1");
        _writeConfig(1, 1, false);
        script.preflight();
    }

    function test_theRuleAtTheRealDepthMatchesTheDatedEvidenceAndTheScriptEnforcesIt() public {
        uint256 depth = IERC20(USDC).balanceOf(POOL);
        assertEq(depth, 13_633_808_211_200, "USDC held by the pool at the pinned block (evidence json)");
        uint256 max = StakeCapRule.maxStakeCap(depth, 30, 30, 500);
        assertApproxEqRel(max, 71_519_274, 1e15, "about 71.52 USDC for a 30 second Window");
        assertApproxEqRel(StakeCapRule.maxStakeCap(depth, 2, 30, 500), 7_449_718, 1e15, "about 7.45 USDC for 2 seconds");

        _writeConfig(max, max, false);
        script.preflight();
        _writeConfig(max + 1, max, false);
        vm.expectPartialRevert(DeployPayerCampaign.StakeCapAboveRule.selector);
        script.preflight();
    }

    function test_theRuleAssumesAPriceMoveTheRealPoolCannotBePushedAnywhereNear() public {
        uint256 depth = IERC20(USDC).balanceOf(POOL);
        // Rule model for a 30 second Window, lookback 30: m = sigma * sqrt(30) * 30 / 2, about 0.82%.
        uint256 assumedMove = 1e14 * 5_477_225_575 / 1e9 * 30 / 2; // sqrt(30) = 5.477225575, in 1e18
        uint256 volume = depth * assumedMove / 2 / 1e18; // quote volume the rule says moves the price by `assumedMove`
        assertGt(volume, 50_000e6, "the rule prices the move at tens of thousands of USDC");

        (uint160 before,,,,,,) = IV3Pool(POOL).slot0();
        deal(USDC, address(this), volume);
        IV3Pool(POOL).swap(address(this), false, int256(volume), MAX_SQRT_RATIO_MINUS_ONE, "");
        (uint160 afterSwap,,,,,,) = IV3Pool(POOL).slot0();

        uint256 sqrtRatio = Math.mulDiv(afterSwap, 1e18, before);
        uint256 realMove = Math.mulDiv(sqrtRatio, sqrtRatio, 1e18) - 1e18;
        emit log_named_uint("assumed relative price move (1e18)", assumedMove);
        emit log_named_uint("realized relative price move (1e18)", realMove);
        assertGt(realMove, 0, "the swap moved the price");
        assertLt(
            realMove, assumedMove, "real depth is deeper than the balance the rule assumes, so the rule is conservative"
        );
    }

    /// @dev Uniswap V3 swap callback: pay the quote token the pool is owed.
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        require(msg.sender == POOL, "not the pool");
        if (amount0Delta > 0) IERC20(WETH).transfer(POOL, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(USDC).transfer(POOL, uint256(amount1Delta));
    }
}

contract ConfiguredScript is DeployPayerCampaign {
    string private s_configPath;

    constructor(string memory configPath_) {
        s_configPath = configPath_;
    }

    function _configPath() internal view override returns (string memory) {
        return s_configPath;
    }
}

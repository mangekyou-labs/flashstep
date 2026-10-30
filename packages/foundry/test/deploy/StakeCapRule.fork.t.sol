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
    uint256 internal constant LOOKBACK = 30;
    uint256 internal constant ONE_TICK = 1e14; // 0.01%, the finest price step a TWAP over integer ticks can show
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
        assertApproxEqRel(max, 33_089_948, 1e15, "about 33.09 USDC for a 30 second Window");
        assertApproxEqRel(StakeCapRule.maxStakeCap(depth, 2, 30, 500), 2_845_839, 1e15, "about 2.85 USDC for 2 seconds");

        _writeConfig(max, max, false);
        script.preflight();
        _writeConfig(max + 1, max, false);
        vm.expectPartialRevert(DeployPayerCampaign.StakeCapAboveRule.selector);
        script.preflight();
    }

    /// @dev What this checks: for the push volume the rule prices, the real pool's spot price moves no more than the
    /// rule's constant product model says, so the real cost of the push is at least what the rule assumes, and the
    /// BasePoolReader Reading follows the spot push diluted by min(Window, lookback) / lookback, to within one tick.
    /// What it does not check: sigma (the natural drift), arbitrageurs undoing the push block by block (the rule
    /// charges a block's fees per held block; nothing here simulates the reversion), or the cited daily volume.
    function test_theRuleBoundsTheRealCostOfMovingTheReading_30SecondWindow() public {
        _checkTheRuleAgainstTheRealPool(30);
    }

    function test_theRuleBoundsTheRealCostOfMovingTheReading_10SecondWindow() public {
        _checkTheRuleAgainstTheRealPool(10);
    }

    function test_theRuleBoundsTheRealCostOfMovingTheReading_2SecondWindow() public {
        _checkTheRuleAgainstTheRealPool(2);
    }

    function _checkTheRuleAgainstTheRealPool(uint256 windowSeconds) internal {
        uint256 depth = IERC20(USDC).balanceOf(POOL);
        uint256 pushAssumed = StakeCapRule.spotPush(windowSeconds, LOOKBACK); // spot push the rule prices
        uint256 volume = depth * pushAssumed / 2 / 1e18; // quote volume the rule says causes it
        uint256 held = Math.min(windowSeconds, LOOKBACK);

        (uint256 readingMove, uint256 spotMove) = _pushAndRead(volume, windowSeconds);
        emit log_named_uint("window seconds", windowSeconds);
        emit log_named_uint("push volume the rule prices (raw USDC)", volume);
        emit log_named_uint("spot push the rule assumes (1e18)", pushAssumed);
        emit log_named_uint("spot push the real pool shows (1e18)", spotMove);
        emit log_named_uint("Reading move the real BasePoolReader shows (1e18)", readingMove);
        emit log_named_uint("Reading move the rule requires (1e18)", StakeCapRule.readingMove(windowSeconds, LOOKBACK));

        assertGt(spotMove, 0, "the swap moved the price");
        assertLe(spotMove, pushAssumed, "the real pool is at least as deep as the balance the rule assumes");
        // The Reading shows the spot push diluted over the lookback. One tick (about 0.01%) is the Reading's resolution.
        assertLe(
            readingMove,
            Math.mulDiv(spotMove, held, LOOKBACK) + ONE_TICK,
            "the Reading cannot move more than the diluted spot push"
        );

        // The real cost to cause the spot push the rule assumes, from the real pool's response to this swap:
        // volume scales with the push for a small push, fees and average slippage are paid for each held block.
        uint256 realVolumeForAssumedPush = Math.mulDiv(volume, pushAssumed, spotMove);
        uint256 feeAndSlip = 2 * 500 * 1e18 / 1_000_000 + pushAssumed / 2;
        uint256 realCostPerBlock = Math.mulDiv(realVolumeForAssumedPush, feeAndSlip, 1e18);
        uint256 realCap =
            StakeCapRule.holdBlocks(windowSeconds, LOOKBACK) * realCostPerBlock / StakeCapRule.SAFETY_DIVISOR;
        uint256 ruleCap = StakeCapRule.maxStakeCap(depth, windowSeconds, LOOKBACK, 500);
        emit log_named_uint("cap the rule allows (raw USDC)", ruleCap);
        emit log_named_uint("cap the real pool's response supports (raw USDC)", realCap);
        assertGe(realCap, ruleCap, "the real pool is deeper than the rule assumes, so the rule's cap is conservative");
    }

    /// @dev Takes the start Reading, pushes the pool by buying the base token with `volume` of the quote token, lets
    /// `windowSeconds` pass at the pushed price (no arbitrage), takes the end Reading, and reverts the fork state.
    function _pushAndRead(uint256 volume, uint256 windowSeconds)
        internal
        returns (uint256 readingMove, uint256 spotMove)
    {
        uint256 snapshot = vm.snapshotState();
        BasePoolReader reader = new BasePoolReader(POOL, WETH, uint32(LOOKBACK));
        uint256 startReading = reader.preview().price;
        (uint160 sqrtBefore,,,,,,) = IV3Pool(POOL).slot0();

        deal(USDC, address(this), volume);
        IV3Pool(POOL).swap(address(this), false, int256(volume), MAX_SQRT_RATIO_MINUS_ONE, "");
        (uint160 sqrtAfter,,,,,,) = IV3Pool(POOL).slot0();
        uint256 sqrtRatio = Math.mulDiv(sqrtAfter, 1e18, sqrtBefore);
        spotMove = Math.mulDiv(sqrtRatio, sqrtRatio, 1e18) - 1e18;

        vm.warp(block.timestamp + windowSeconds);
        vm.roll(block.number + (windowSeconds + 1) / 2);
        uint256 endReading = reader.preview().price;
        readingMove = endReading > startReading ? Math.mulDiv(endReading, 1e18, startReading) - 1e18 : 0;
        vm.revertToState(snapshot);
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

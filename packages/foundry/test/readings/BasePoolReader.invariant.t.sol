// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { BasePoolReader } from "../../contracts/readings/BasePoolReader.sol";
import { MockBasePool, MockReadingToken } from "../mocks/MockBasePool.sol";

/// @notice Drives one reader through time, pool writes, missing observations and repeated captures.
contract BasePoolReaderHandler is Test {
    uint32 internal constant LOOKBACK = 30;

    BasePoolReader public immutable i_reader;
    MockBasePool public immutable i_pool;

    /// @dev First Reading seen for each captured block; it must never change afterwards.
    mapping(uint256 => BasePoolReader.Reading) public s_firstSeen;
    uint256[] public s_capturedBlocks;
    /// @dev Every block the run has visited, captured or not.
    uint256[] public s_visitedBlocks;
    mapping(uint256 => bool) internal s_visited;

    /// @dev Set when capture() disagrees with the first Reading or fails without a scripted cause.
    bool public s_captureChanged;
    bool public s_unexplainedFailure;

    uint256 public s_captures;
    uint256 public s_repeatCaptures;
    uint256 public s_failedCaptures;
    uint256 public s_writes;
    uint256 public s_advances;
    uint256 public s_missingToggles;

    constructor(BasePoolReader reader_, MockBasePool pool_) {
        i_reader = reader_;
        i_pool = pool_;
        _visit();
    }

    /// Move to a later block; Base blocks are 2 seconds apart, so time advances with them.
    function advance(uint256 blocksSeed) external {
        uint256 blocks = bound(blocksSeed, 1, 15);
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + 2 * blocks);
        ++s_advances;
        _visit();
    }

    /// Move time without a new block. Base never does this, but it makes a same-block re-capture
    /// see a different TWAP, so only the first-capture-wins rule can keep the Reading unchanged.
    function warpWithinBlock(uint256 secondsSeed) external {
        vm.warp(block.timestamp + bound(secondsSeed, 1, 2));
        ++s_advances;
    }

    /// Write a new tick in the current block, including after a capture in this block.
    function writeTick(int256 tickSeed) external {
        i_pool.write(int24(bound(tickSeed, -200_000, 200_000)));
        ++s_writes;
    }

    /// Fail observe() for the current block only, or clear that failure.
    function toggleMissingAtCurrentBlock() external {
        i_pool.setMissingAtBlock(block.number, !i_pool.missingAtBlock(block.number));
        ++s_missingToggles;
    }

    function capture() external {
        bool alreadyCaptured = s_firstSeen[block.number].timestamp != 0;
        try i_reader.capture() returns (BasePoolReader.Reading memory reading) {
            if (alreadyCaptured) {
                ++s_repeatCaptures;
                if (!_same(reading, s_firstSeen[block.number])) s_captureChanged = true;
            } else {
                ++s_captures;
                s_firstSeen[block.number] = reading;
                s_capturedBlocks.push(block.number);
                if (reading.blockNumber != block.number || reading.timestamp != block.timestamp) {
                    s_captureChanged = true;
                }
            }
        } catch {
            ++s_failedCaptures;
            // History always covers the lookback, so only a scripted missing block may fail.
            if (alreadyCaptured || !i_pool.missingAtBlock(block.number)) s_unexplainedFailure = true;
        }
    }

    function capturedCount() external view returns (uint256) {
        return s_capturedBlocks.length;
    }

    function visitedCount() external view returns (uint256) {
        return s_visitedBlocks.length;
    }

    function firstSeen(uint256 blockNumber) external view returns (BasePoolReader.Reading memory) {
        return s_firstSeen[blockNumber];
    }

    function _visit() internal {
        if (s_visited[block.number]) return;
        s_visited[block.number] = true;
        s_visitedBlocks.push(block.number);
    }

    function _same(BasePoolReader.Reading memory a, BasePoolReader.Reading memory b) internal pure returns (bool) {
        return a.blockNumber == b.blockNumber && a.timestamp == b.timestamp && a.price == b.price;
    }
}

contract BasePoolReaderInvariantTest is Test {
    BasePoolReader internal reader;
    BasePoolReaderHandler internal handler;

    function setUp() public {
        vm.roll(500);
        vm.warp(1_000);
        MockReadingToken base = new MockReadingToken(18, 0);
        MockReadingToken quote = new MockReadingToken(18, 0);
        MockBasePool pool = new MockBasePool(address(base), address(quote));
        pool.write(0);
        reader = new BasePoolReader(address(pool), address(base), 30);
        // Start with a full lookback of history so only scripted gaps can fail a capture.
        vm.roll(515);
        vm.warp(1_030);
        handler = new BasePoolReaderHandler(reader, pool);
        targetContract(address(handler));
        bytes4[] memory actions = new bytes4[](5);
        actions[0] = BasePoolReaderHandler.advance.selector;
        actions[1] = BasePoolReaderHandler.writeTick.selector;
        actions[2] = BasePoolReaderHandler.toggleMissingAtCurrentBlock.selector;
        actions[3] = BasePoolReaderHandler.capture.selector;
        actions[4] = BasePoolReaderHandler.warpWithinBlock.selector;
        targetSelector(StdInvariant.FuzzSelector({ addr: address(handler), selectors: actions }));
    }

    /// forge-config: default.invariant.runs = 128
    /// forge-config: default.invariant.depth = 100
    /// forge-config: default.invariant.fail-on-revert = true
    /// forge-config: default.invariant.show-metrics = true
    function invariant_capturedReadingsNeverChange() public view {
        assertFalse(handler.s_captureChanged());
        uint256 count = handler.capturedCount();
        for (uint256 i; i < count; ++i) {
            uint256 blockNumber = handler.s_capturedBlocks(i);
            BasePoolReader.Reading memory first = handler.firstSeen(blockNumber);
            BasePoolReader.Reading memory stored = reader.read(blockNumber);
            assertEq(stored.blockNumber, first.blockNumber);
            assertEq(stored.timestamp, first.timestamp);
            assertEq(stored.price, first.price);
        }
    }

    /// forge-config: default.invariant.runs = 128
    /// forge-config: default.invariant.depth = 100
    /// forge-config: default.invariant.fail-on-revert = true
    /// forge-config: default.invariant.show-metrics = true
    function invariant_uncapturedBlocksHaveNoReading() public view {
        uint256 count = handler.visitedCount();
        for (uint256 i; i < count; ++i) {
            uint256 blockNumber = handler.s_visitedBlocks(i);
            if (handler.firstSeen(blockNumber).timestamp != 0) continue;
            try reader.read(blockNumber) returns (BasePoolReader.Reading memory) {
                revert("uncaptured block has a Reading");
            } catch (bytes memory reason) {
                assertEq(reason, abi.encodeWithSelector(BasePoolReader.NoValidReading.selector));
            }
        }
        // Blocks after the current one are never readable.
        try reader.read(block.number + 1) returns (BasePoolReader.Reading memory) {
            revert("future block has a Reading");
        } catch { }
    }

    /// forge-config: default.invariant.runs = 128
    /// forge-config: default.invariant.depth = 100
    /// forge-config: default.invariant.fail-on-revert = true
    /// forge-config: default.invariant.show-metrics = true
    function invariant_onlyScriptedGapsFailCapture() public view {
        assertFalse(handler.s_unexplainedFailure());
    }

    function afterInvariant() external view {
        // Surfaces how much state each run reached; visible with -vv.
        console.log("captures", handler.s_captures(), "repeat captures", handler.s_repeatCaptures());
        console.log("failed captures", handler.s_failedCaptures(), "writes", handler.s_writes());
        console.log("advances", handler.s_advances(), "missing toggles", handler.s_missingToggles());
    }
}

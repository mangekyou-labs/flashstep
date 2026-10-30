// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { MockBasePool } from "./MockBasePool.sol";

/// @notice A Uniswap v3 factory fixture: only the registry the deploy script's vetting reads.
contract MockV3Factory {
    mapping(bytes32 => address) private s_pools;

    function setPool(address a, address b, uint24 fee, address pool) external {
        s_pools[_key(a, b, fee)] = pool;
    }

    function getPool(address a, address b, uint24 fee) external view returns (address) {
        return s_pools[_key(a, b, fee)];
    }

    function _key(address a, address b, uint24 fee) private pure returns (bytes32) {
        (address lo, address hi) = a < b ? (a, b) : (b, a);
        return keccak256(abi.encode(lo, hi, fee));
    }
}

/// @notice A scripted pool that also answers the identity calls a real v3 pool answers.
contract MockV3Pool is MockBasePool {
    address public immutable factory;
    uint24 public immutable fee;

    constructor(address factory_, address token0_, address token1_, uint24 fee_) MockBasePool(token0_, token1_) {
        factory = factory_;
        fee = fee_;
    }
}

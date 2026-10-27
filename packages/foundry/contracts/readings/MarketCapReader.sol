// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC5805 } from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BasePoolReader } from "./BasePoolReader.sol";

/// @notice Resolves market-cap Readings only from eligible end-block supply sources.
/// @dev Deployment must vet token code: Fixed requires immutable supply and implementation;
/// Checkpoints requires truthful historical total-supply checkpoints. Interface checks cannot
/// establish either guarantee. Unsupported tokens remain usable through the price reader alone.
contract MarketCapReader {
    error InvalidSupplyConfiguration();
    error NoValidMarketCap();

    enum SupplyMode {
        Unsupported,
        Fixed,
        Checkpoints
    }

    struct MarketCapReading {
        BasePoolReader.Reading reading;
        uint256 totalSupply; // Raw base-token units at the end of reading.blockNumber.
        uint256 marketCap; // Whole quote tokens, scaled by BasePoolReader.PRICE_SCALE (1e36).
    }

    BasePoolReader public immutable priceReader;
    address public immutable token;
    SupplyMode public immutable supplyMode;
    uint256 public immutable fixedSupply;

    /// @param vettedFixedSupply Raw immutable supply, explicitly vetted before choosing Fixed mode.
    /// Matching current totalSupply is only a configuration sanity check, not proof of eligibility.
    constructor(BasePoolReader priceReader_, SupplyMode mode, uint256 vettedFixedSupply) {
        priceReader = priceReader_;
        token = address(priceReader_.token());
        supplyMode = mode;
        fixedSupply = vettedFixedSupply;
        if (mode == SupplyMode.Fixed) {
            if (vettedFixedSupply == 0) revert InvalidSupplyConfiguration();
            try IERC20(token).totalSupply() returns (uint256 supply) {
                if (supply != vettedFixedSupply) revert InvalidSupplyConfiguration();
            } catch {
                revert InvalidSupplyConfiguration();
            }
        } else if (vettedFixedSupply != 0) {
            revert InvalidSupplyConfiguration();
        }
    }

    /// @notice The endpoint must be a completed block; current execution supply is never used.
    function readMarketCap(uint256 endBlock) external view returns (MarketCapReading memory result) {
        if (endBlock >= block.number || supplyMode == SupplyMode.Unsupported) revert NoValidMarketCap();
        try priceReader.read(endBlock) returns (BasePoolReader.Reading memory reading) {
            result.reading = reading;
        } catch {
            revert NoValidMarketCap();
        }
        if (supplyMode == SupplyMode.Fixed) {
            result.totalSupply = fixedSupply;
        } else {
            IERC5805 checkpoints = IERC5805(token);
            try checkpoints.CLOCK_MODE() returns (string memory mode) {
                if (keccak256(bytes(mode)) != keccak256("mode=blocknumber&from=default")) revert NoValidMarketCap();
            } catch {
                revert NoValidMarketCap();
            }
            try checkpoints.clock() returns (uint48 currentClock) {
                if (uint256(currentClock) != block.number) revert NoValidMarketCap();
            } catch {
                revert NoValidMarketCap();
            }
            try checkpoints.getPastTotalSupply(endBlock) returns (uint256 supply) {
                result.totalSupply = supply;
            } catch {
                revert NoValidMarketCap();
            }
        }
        result.marketCap = Math.mulDiv(result.reading.price, result.totalSupply, priceReader.tokenUnit());
    }
}

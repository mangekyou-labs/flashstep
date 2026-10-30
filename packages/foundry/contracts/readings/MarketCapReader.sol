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

    BasePoolReader public immutable i_priceReader;
    address public immutable i_baseToken;
    SupplyMode public immutable i_supplyMode;
    uint256 public immutable i_fixedSupply;

    /// @param vettedFixedSupply Raw immutable supply, explicitly vetted before choosing Fixed mode.
    /// Matching current totalSupply is only a configuration sanity check, not proof of eligibility.
    constructor(BasePoolReader priceReader_, SupplyMode mode, uint256 vettedFixedSupply) {
        i_priceReader = priceReader_;
        i_baseToken = address(priceReader_.i_baseToken());
        i_supplyMode = mode;
        i_fixedSupply = vettedFixedSupply;
        if (mode == SupplyMode.Fixed) {
            if (vettedFixedSupply == 0) revert InvalidSupplyConfiguration();
            try IERC20(i_baseToken).totalSupply() returns (uint256 supply) {
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
        if (endBlock >= block.number || i_supplyMode == SupplyMode.Unsupported) revert NoValidMarketCap();
        try i_priceReader.read(endBlock) returns (BasePoolReader.Reading memory reading) {
            result.reading = reading;
        } catch {
            revert NoValidMarketCap();
        }
        return _withSupply(result, endBlock);
    }

    /// @notice Live display only; settlement still requires a captured, completed endpoint.
    /// Checkpoint supply comes from the last completed block, never the executing block.
    function previewMarketCap() external view returns (MarketCapReading memory result) {
        if (i_supplyMode == SupplyMode.Unsupported || block.number == 0) revert NoValidMarketCap();
        result.reading = i_priceReader.preview();
        return _withSupply(result, block.number - 1);
    }

    function _withSupply(MarketCapReading memory result, uint256 endBlock)
        private
        view
        returns (MarketCapReading memory)
    {
        if (i_supplyMode == SupplyMode.Fixed) {
            result.totalSupply = i_fixedSupply;
        } else {
            IERC5805 checkpoints = IERC5805(i_baseToken);
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
        uint256 baseUnit = i_priceReader.i_baseUnit();
        (uint256 high,) = Math.mul512(result.reading.price, result.totalSupply);
        if (high >= baseUnit) revert NoValidMarketCap(); // Math.mulDiv would panic past uint256.
        result.marketCap = Math.mulDiv(result.reading.price, result.totalSupply, baseUnit);
        return result;
    }
}

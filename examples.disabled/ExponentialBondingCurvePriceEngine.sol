// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";
import "@openzeppelin/utils/math/Math.sol";
import "../IPriceEngine.sol";

/**
 * @title Exponential Bonding Curve Price Engine
 * @notice Implements an exponential bonding curve where price increases
 *         exponentially with each token sold: price = basePrice * (multiplier ^ alreadyMinted)
 * 
 * @dev Uses fixed-point math with 18 decimal precision for the multiplier.
 *      For example, multiplier = 1.05e18 means 5% increase per token.
 */
contract ExponentialBondingCurvePriceEngine is IPriceEngine, ERC165 {
    using Math for uint256;

    /// @dev Base price (price for the first token)
    uint256 public immutable basePrice;

    /// @dev Multiplier per token (as fixed-point with 18 decimals)
    ///      Example: 1.05e18 = 5% increase per token
    uint256 public immutable multiplier;

    /// @dev Precision constant for fixed-point math (18 decimals)
    uint256 private constant PRECISION = 1e18;

    /**
     * @param _basePrice The starting price (in wei)
     * @param _multiplier The multiplier per token (as fixed-point, e.g., 1.05e18 for 5%)
     */
    constructor(uint256 _basePrice, uint256 _multiplier) {
        require(_basePrice > 0, "ExponentialBondingCurvePriceEngine: Base price must be > 0");
        require(_multiplier > PRECISION, "ExponentialBondingCurvePriceEngine: Multiplier must be > 1");
        basePrice = _basePrice;
        multiplier = _multiplier;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IPriceEngine).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IPriceEngine-price}
     * 
     * Formula: price = basePrice * (multiplier ^ alreadyMinted)
     * 
     * @param assetId Ignored for this implementation (all assets use same curve)
     * @param alreadyMinted Number of tokens already minted
     * @param count Number of tokens being purchased (must be 1 for lazy mints)
     */
    function price(uint256 assetId, uint256 alreadyMinted, uint24 count) 
        external 
        view 
        override 
        returns (uint256) 
    {
        require(count == 1, "ExponentialBondingCurvePriceEngine: Count must be 1");
        
        if (alreadyMinted == 0) {
            return basePrice;
        }

        // Calculate multiplier ^ alreadyMinted using repeated multiplication
        // For small values, this is efficient. For large values, consider using logarithms
        uint256 result = PRECISION;
        for (uint256 i = 0; i < alreadyMinted; i++) {
            result = (result * multiplier) / PRECISION;
        }

        return (basePrice * result) / PRECISION;
    }
}


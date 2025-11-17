// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";
import "../IPriceEngine.sol";

/**
 * @title Linear Bonding Curve Price Engine
 * @notice Implements a linear bonding curve where price increases linearly
 *         with each token sold: price = basePrice + (alreadyMinted * increment)
 * 
 * @dev Perfect for simple bonding curves where price increases by a fixed
 *      amount per token sold.
 */
contract LinearBondingCurvePriceEngine is IPriceEngine, ERC165 {
    /// @dev Base price (price for the first token)
    uint256 public immutable basePrice;

    /// @dev Price increment per token sold
    uint256 public immutable increment;

    /**
     * @param _basePrice The starting price (in wei)
     * @param _increment The price increase per token sold (in wei)
     */
    constructor(uint256 _basePrice, uint256 _increment) {
        require(_basePrice > 0, "LinearBondingCurvePriceEngine: Base price must be > 0");
        basePrice = _basePrice;
        increment = _increment;
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
     * Formula: price = basePrice + (alreadyMinted * increment)
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
        require(count == 1, "LinearBondingCurvePriceEngine: Count must be 1");
        
        // Price increases linearly: basePrice + (alreadyMinted * increment)
        return basePrice + (alreadyMinted * increment);
    }
}


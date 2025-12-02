// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";
import "@openzeppelin/utils/math/Math.sol";
import "../IPriceEngine.sol";

/**
 * @title Dutch Auction Price Engine
 * @notice Implements a Dutch auction where price decreases over time based on
 *         block timestamp. Price starts high and decreases linearly until it
 *         reaches the reserve price.
 * 
 * @dev The price decreases linearly from startPrice to reservePrice over
 *      the duration period. After the duration, price remains at reservePrice.
 */
contract DutchAuctionPriceEngine is IPriceEngine, ERC165 {
    using Math for uint256;

    /// @dev Starting price (highest price)
    uint256 public immutable startPrice;

    /// @dev Reserve price (lowest price)
    uint256 public immutable reservePrice;

    /// @dev Auction start timestamp
    uint256 public immutable startTime;

    /// @dev Auction duration in seconds
    uint256 public immutable duration;

    /**
     * @param _startPrice The starting price (in wei)
     * @param _reservePrice The reserve price (in wei)
     * @param _startTime The auction start timestamp
     * @param _duration The auction duration in seconds
     */
    constructor(
        uint256 _startPrice,
        uint256 _reservePrice,
        uint256 _startTime,
        uint256 _duration
    ) {
        require(_startPrice > _reservePrice, "DutchAuctionPriceEngine: Start price must be > reserve");
        require(_duration > 0, "DutchAuctionPriceEngine: Duration must be > 0");
        startPrice = _startPrice;
        reservePrice = _reservePrice;
        startTime = _startTime;
        duration = _duration;
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
     * Formula: price = startPrice - ((startPrice - reservePrice) * elapsed / duration)
     * 
     * @param assetId Ignored for this implementation
     * @param alreadyMinted Ignored for this implementation (time-based, not quantity-based)
     * @param count Number of tokens being purchased (must be 1 for lazy mints)
     */
    function price(uint256 assetId, uint256 alreadyMinted, uint24 count) 
        external 
        view 
        override 
        returns (uint256) 
    {
        require(count == 1, "DutchAuctionPriceEngine: Count must be 1");
        
        uint256 currentTime = block.timestamp;
        
        // If auction hasn't started, return start price
        if (currentTime < startTime) {
            return startPrice;
        }

        // Calculate elapsed time
        uint256 elapsed = currentTime - startTime;
        
        // If duration has passed, return reserve price
        if (elapsed >= duration) {
            return reservePrice;
        }

        // Calculate price decrease
        uint256 priceDecrease = ((startPrice - reservePrice) * elapsed) / duration;
        
        // Current price = start price - price decrease
        uint256 currentPrice = startPrice - priceDecrease;
        
        // Ensure price doesn't go below reserve
        return Math.max(currentPrice, reservePrice);
    }
}


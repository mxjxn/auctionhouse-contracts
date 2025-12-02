// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";
import "../IPriceEngine.sol";

/**
 * @title Step Pricing Engine
 * @notice Implements step pricing where price changes at specific quantity thresholds.
 *         Each step defines a quantity range and the price for that range.
 * 
 * @dev Useful for tiered pricing models where price changes at specific milestones.
 *      Example: First 10 tokens at 0.1 ETH, next 20 at 0.2 ETH, etc.
 */
contract StepPricingEngine is IPriceEngine, ERC165 {
    /// @dev Represents a pricing step
    struct PricingStep {
        uint256 quantity; // Quantity threshold (cumulative)
        uint256 price;     // Price for this step
    }

    /// @dev Array of pricing steps (must be sorted by quantity)
    PricingStep[] public steps;

    /**
     * @param _steps Array of pricing steps (must be sorted by quantity ascending)
     */
    constructor(PricingStep[] memory _steps) {
        require(_steps.length > 0, "StepPricingEngine: Must have at least one step");
        
        uint256 lastQuantity = 0;
        for (uint256 i = 0; i < _steps.length; i++) {
            require(_steps[i].quantity > lastQuantity, "StepPricingEngine: Steps must be sorted and unique");
            require(_steps[i].price > 0, "StepPricingEngine: Price must be > 0");
            steps.push(_steps[i]);
            lastQuantity = _steps[i].quantity;
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IPriceEngine).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Get the number of pricing steps
     */
    function getStepCount() external view returns (uint256) {
        return steps.length;
    }

    /**
     * @dev See {IPriceEngine-price}
     * 
     * Finds the appropriate step based on alreadyMinted quantity.
     * 
     * @param assetId Ignored for this implementation
     * @param alreadyMinted Number of tokens already minted
     * @param count Number of tokens being purchased (must be 1 for lazy mints)
     */
    function price(uint256 assetId, uint256 alreadyMinted, uint24 count) 
        external 
        view 
        override 
        returns (uint256) 
    {
        require(count == 1, "StepPricingEngine: Count must be 1");
        
        // Find the appropriate step
        // Use the price for the step where alreadyMinted < step.quantity
        // If alreadyMinted is >= all steps, use the last step's price
        
        for (uint256 i = 0; i < steps.length; i++) {
            if (alreadyMinted < steps[i].quantity) {
                return steps[i].price;
            }
        }
        
        // If we've exceeded all steps, use the last step's price
        return steps[steps.length - 1].price;
    }
}


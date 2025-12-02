// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@manifoldxyz/royalty-registry-solidity/IRoyaltyEngineV1.sol";

/**
 * @title MockRoyaltyEngine
 * @notice Mock royalty engine for testing on networks without a deployed Manifold Royalty Registry.
 * Returns empty royalties for all tokens, allowing marketplace functionality to work without
 * actual royalty lookups.
 * 
 * @dev This contract implements IRoyaltyEngineV1 and IERC165 to be compatible with
 * the marketplace's royalty engine interface.
 */
contract MockRoyaltyEngine is ERC165, IRoyaltyEngineV1 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyEngineV1).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Get royalty information for a token.
     * @param tokenAddress The address of the token contract
     * @param tokenId The token ID
     * @param value The sale value
     * @return recipients Array of royalty recipient addresses (empty for mock)
     * @return amounts Array of royalty amounts (empty for mock)
     */
    function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value)
        external
        pure
        override
        returns (address payable[] memory recipients, uint256[] memory amounts)
    {
        // Return empty arrays - no royalties for testing
        recipients = new address payable[](0);
        amounts = new uint256[](0);
        
        // Silence unused parameter warnings
        tokenAddress;
        tokenId;
        value;
    }

    /**
     * @dev View-only version of getRoyalty.
     * @param tokenAddress The address of the token contract
     * @param tokenId The token ID
     * @param value The sale value
     * @return recipients Array of royalty recipient addresses (empty for mock)
     * @return amounts Array of royalty amounts (empty for mock)
     */
    function getRoyaltyView(address tokenAddress, uint256 tokenId, uint256 value)
        external
        pure
        override
        returns (address payable[] memory recipients, uint256[] memory amounts)
    {
        // Return empty arrays - no royalties for testing
        recipients = new address payable[](0);
        amounts = new uint256[](0);
        
        // Silence unused parameter warnings
        tokenAddress;
        tokenId;
        value;
    }
}


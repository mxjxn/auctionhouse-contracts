// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/interfaces/IERC165.sol";
import "./IMarketplaceSellerRegistry.sol";

contract MembershipSellerRegistry is IMarketplaceSellerRegistry {
    IERC721 private nftContract;

    constructor(address _nftContractAddress) {
        nftContract = IERC721(_nftContractAddress);
    }

    /**
     *  @dev Check if seller is authorized
     *
     *  @param seller         Address of seller
     *  @param data           Additional data needed to verify (not used in this implementation)
     */
    function isAuthorized(address seller, bytes calldata data) external view override returns (bool) {
        // Check if the seller has any NFTs from the specified contract
        return nftContract.balanceOf(seller) > 0;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IMarketplaceSellerRegistry).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

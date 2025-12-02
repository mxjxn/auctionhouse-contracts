// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @author: manifold.xyz

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/utils/introspection/ERC165.sol";
import "../ILazyDelivery.sol";
import "../../creator-core-contracts/contracts/core/IERC721CreatorCore.sol";

/**
 * @title ERC721 Creator Lazy Delivery Adapter
 * @notice Adapter contract that enables Manifold Creator Core ERC721 contracts
 *         to work with the auctionhouse marketplace's lazy minting system.
 * 
 * @dev This adapter implements ILazyDelivery and calls mintExtension() on the
 *      Creator Core contract. The adapter must be registered as an extension
 *      on the Creator Core contract before it can mint tokens.
 * 
 * @dev The adapter restricts delivery calls to authorized marketplace addresses
 *      to prevent unauthorized minting.
 */
contract ERC721CreatorLazyDelivery is ILazyDelivery, ERC165 {
    using ERC165Checker for address;

    /// @dev Mapping of authorized marketplace addresses
    mapping(address => bool) private _authorizedMarketplaces;

    /// @dev The Creator Core contract this adapter is connected to
    address public immutable creatorContract;

    /// @dev Mapping to track minted tokens per listing (for assetId tracking)
    mapping(uint40 => uint256) private _totalMintedForListing;

    /**
     * @dev Emitted when a marketplace is authorized or unauthorized
     */
    event MarketplaceAuthorizationUpdated(address indexed marketplace, bool authorized);

    /**
     * @dev Emitted when a token is delivered via lazy minting
     */
    event TokenDelivered(uint40 indexed listingId, address indexed to, uint256 tokenId, uint256 assetId);

    /**
     * @dev Modifier to ensure only authorized marketplaces can call deliver
     */
    modifier onlyAuthorizedMarketplace() {
        require(_authorizedMarketplaces[msg.sender], "ERC721CreatorLazyDelivery: Unauthorized marketplace");
        _;
    }

    /**
     * @dev Modifier to ensure recipient is not a contract (prevents exploit)
     */
    modifier onlyEOA(address to) {
        require(to.code.length == 0, "ERC721CreatorLazyDelivery: Cannot deliver to contract");
        _;
    }

    /**
     * @param _creatorContract The address of the Creator Core ERC721 contract
     */
    constructor(address _creatorContract) {
        require(
            _creatorContract.supportsInterface(type(IERC721CreatorCore).interfaceId),
            "ERC721CreatorLazyDelivery: Invalid creator contract"
        );
        creatorContract = _creatorContract;
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(ILazyDelivery).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Authorize or unauthorize a marketplace address
     * @param marketplace The marketplace contract address
     * @param authorized Whether to authorize or unauthorize
     * 
     * @dev NOTE: This function currently allows any caller. In production,
     *      you should add proper access control checks. For example:
     *      - Only allow the creator contract owner/admin
     *      - Use AdminControl pattern from libraries-solidity
     *      - Implement ownable pattern
     */
    function setAuthorizedMarketplace(address marketplace, bool authorized) external {
        // TODO: Add proper access control here
        // Example: require(msg.sender == Ownable(creatorContract).owner(), "Unauthorized");
        require(marketplace != address(0), "ERC721CreatorLazyDelivery: Invalid marketplace address");
        _authorizedMarketplaces[marketplace] = authorized;
        emit MarketplaceAuthorizationUpdated(marketplace, authorized);
    }

    /**
     * @dev Check if a marketplace is authorized
     */
    function isAuthorizedMarketplace(address marketplace) external view returns (bool) {
        return _authorizedMarketplaces[marketplace];
    }

    /**
     * @dev See {ILazyDelivery-deliver}
     * 
     * @param listingId The listing ID from the marketplace
     * @param to The address to deliver the token to
     * @param assetId The asset ID (used for tracking/token selection)
     * @param payableCount Must be 1 for ERC721
     * @param payableAmount The amount seller will receive (for reference)
     * @param payableERC20 The ERC20 token address (0x0 for ETH)
     * @param index Optional index value for certain sales methods
     */
    function deliver(
        uint40 listingId,
        address to,
        uint256 assetId,
        uint24 payableCount,
        uint256 payableAmount,
        address payableERC20,
        uint256 index
    ) external override onlyAuthorizedMarketplace onlyEOA(to) {
        require(payableCount == 1, "ERC721CreatorLazyDelivery: Must deliver exactly 1 token");

        // Increment mint count for this listing
        _totalMintedForListing[listingId]++;

        // Mint token using extension minting
        // The assetId can be used to encode additional data via uint80 data parameter
        uint80 tokenData = uint80(assetId << 24 | (_totalMintedForListing[listingId] & 0xFFFFFF));
        
        uint256 tokenId = IERC721CreatorCore(creatorContract).mintExtension(to, tokenData);

        emit TokenDelivered(listingId, to, tokenId, assetId);
    }
}


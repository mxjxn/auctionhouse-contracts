// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "./IMarketplaceSellerRegistry.sol";

/**
 * @title MembershipAllowlistRegistry
 * @notice Registry that allows membership holders to associate additional addresses
 *         (like Farcaster verified wallets) so those addresses can also sell on the marketplace.
 * @dev Implements IMarketplaceSellerRegistry to work with the marketplace contract.
 */
contract MembershipAllowlistRegistry is IMarketplaceSellerRegistry {
    /// @dev The ERC721 contract that represents membership NFTs
    IERC721 private nftContract;

    /// @dev Mapping from associated address to the membership holder that registered it
    ///      Zero address means no association exists
    mapping(address => address) public associatedToMembership;

    /// @dev Mapping from membership holder to count of associated addresses
    ///      Used for enumeration and tracking purposes
    mapping(address => uint256) public membershipAssociatedCount;

    /// @dev Event emitted when an address is associated with a membership holder
    event AssociatedAddressAdded(address indexed membershipHolder, address indexed associatedAddress);

    /// @dev Event emitted when an address is disassociated from a membership holder
    event AssociatedAddressRemoved(address indexed membershipHolder, address indexed associatedAddress);

    /**
     * @notice Constructs the MembershipAllowlistRegistry
     * @param _nftContractAddress The address of the ERC721 contract that represents membership
     */
    constructor(address _nftContractAddress) {
        require(_nftContractAddress != address(0), "MembershipAllowlistRegistry: Invalid NFT contract address");
        nftContract = IERC721(_nftContractAddress);
    }

    /**
     * @dev Check if seller is authorized
     *      First checks direct membership, then checks if address is associated with a membership holder
     *
     * @param seller Address of seller to check
     * @return bool  True if seller is authorized, false otherwise
     */
    function isAuthorized(address seller, bytes calldata /* data */) external view override returns (bool) {
        // PRIORITY 1: Check if seller directly holds membership NFT (fast path)
        if (nftContract.balanceOf(seller) > 0) {
            return true;
        }

        // PRIORITY 2: Check if seller is associated with a membership holder (fallback path)
        address membershipHolder = associatedToMembership[seller];

        // No association found
        if (membershipHolder == address(0)) {
            return false;
        }

        // CRITICAL SECURITY CHECK: Verify membership holder still has active membership
        // This prevents stale associations if membership expires or is transferred
        return nftContract.balanceOf(membershipHolder) > 0;
    }

    /**
     * @notice Allows a membership holder to register an associated address
     * @dev Only callable by addresses that hold membership NFTs
     *      Idempotent - can be called multiple times with same address safely
     *
     * @param associatedAddress The address to associate with the caller's membership
     */
    function addAssociatedAddress(address associatedAddress) external {
        // CRITICAL: Only membership holders can register associated addresses
        require(
            nftContract.balanceOf(msg.sender) > 0,
            "MembershipAllowlistRegistry: Caller must hold membership"
        );

        // Validate input address
        require(
            associatedAddress != address(0),
            "MembershipAllowlistRegistry: Cannot associate zero address"
        );

        // Prevent self-association (redundant - they already have direct membership)
        require(
            associatedAddress != msg.sender,
            "MembershipAllowlistRegistry: Cannot associate own address"
        );

        // Check if address is already associated
        address existingHolder = associatedToMembership[associatedAddress];

        // Case 1: Already associated with the same membership holder (idempotent)
        if (existingHolder == msg.sender) {
            // Already registered, silently succeed (no-op for idempotency)
            return;
        }

        // Case 2: Associated with a DIFFERENT membership holder
        if (existingHolder != address(0)) {
            revert("MembershipAllowlistRegistry: Address already associated with different holder");
        }

        // Create association
        associatedToMembership[associatedAddress] = msg.sender;
        membershipAssociatedCount[msg.sender]++;

        emit AssociatedAddressAdded(msg.sender, associatedAddress);
    }

    /**
     * @notice Allows a membership holder to remove an associated address
     * @dev Only callable by the membership holder who registered the address
     *
     * @param associatedAddress The address to disassociate from the caller's membership
     */
    function removeAssociatedAddress(address associatedAddress) external {
        // Lookup the membership holder for this associated address
        address membershipHolder = associatedToMembership[associatedAddress];

        // Check if association exists
        require(
            membershipHolder != address(0),
            "MembershipAllowlistRegistry: Address not associated"
        );

        // Check if caller is the membership holder who registered this address
        require(
            membershipHolder == msg.sender,
            "MembershipAllowlistRegistry: Only membership holder can remove"
        );

        // Remove the association
        delete associatedToMembership[associatedAddress];

        // Decrement counter (with underflow protection)
        if (membershipAssociatedCount[msg.sender] > 0) {
            membershipAssociatedCount[msg.sender]--;
        }

        emit AssociatedAddressRemoved(msg.sender, associatedAddress);
    }

    /**
     * @notice Get the membership holder for an associated address
     * @param associatedAddress The associated address to lookup
     * @return The membership holder address, or zero address if not associated
     */
    function getMembershipHolder(address associatedAddress) external view returns (address) {
        return associatedToMembership[associatedAddress];
    }

    /**
     * @notice Get the NFT contract address used for membership verification
     * @return The address of the membership NFT contract
     */
    function getNftContract() external view returns (address) {
        return address(nftContract);
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IMarketplaceSellerRegistry).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}


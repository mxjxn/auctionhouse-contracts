// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./IMarketplaceSellerRegistry.sol";

/**
 * @title MembershipAllowlistRegistrySecure
 * @notice Secure registry that allows membership holders to associate additional addresses
 *         (like Farcaster verified wallets) so those addresses can also sell on the marketplace.
 * @dev Implements IMarketplaceSellerRegistry to work with the marketplace contract.
 *      SECURITY: Requires signature from the associated address to prove ownership/consent.
 *      This prevents address spoofing attacks where someone could claim to control addresses they don't own.
 */
contract MembershipAllowlistRegistrySecure is IMarketplaceSellerRegistry {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @dev The ERC721 contract that represents membership NFTs
    IERC721 private nftContract;

    /// @dev Mapping from associated address to the membership holder that registered it
    ///      Zero address means no association exists
    mapping(address => address) public associatedToMembership;

    /// @dev Mapping from membership holder to count of associated addresses
    ///      Used for enumeration and tracking purposes
    mapping(address => uint256) public membershipAssociatedCount;

    /// @dev Nonces for replay protection on signatures
    mapping(address => uint256) public nonces;

    /// @dev Event emitted when an address is associated with a membership holder
    event AssociatedAddressAdded(address indexed membershipHolder, address indexed associatedAddress);

    /// @dev Event emitted when an address is disassociated from a membership holder
    event AssociatedAddressRemoved(address indexed membershipHolder, address indexed associatedAddress);

    /**
     * @notice Constructs the MembershipAllowlistRegistrySecure
     * @param _nftContractAddress The address of the ERC721 contract that represents membership
     */
    constructor(address _nftContractAddress) {
        require(_nftContractAddress != address(0), "MembershipAllowlistRegistrySecure: Invalid NFT contract address");
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
     * @notice Allows a membership holder to register an associated address with proof of ownership
     * @dev Only callable by addresses that hold membership NFTs
     *      SECURITY: Requires a signature from the associated address to prove they consent
     *
     * @param associatedAddress The address to associate with the caller's membership
     * @param signature The signature from associatedAddress proving consent (signs: membershipHolder, nonce, chainId, contractAddress)
     */
    function addAssociatedAddress(address associatedAddress, bytes calldata signature) external {
        // CRITICAL: Only membership holders can register associated addresses
        require(
            nftContract.balanceOf(msg.sender) > 0,
            "MembershipAllowlistRegistrySecure: Caller must hold membership"
        );

        // Validate input address
        require(
            associatedAddress != address(0),
            "MembershipAllowlistRegistrySecure: Cannot associate zero address"
        );

        // Prevent self-association (redundant - they already have direct membership)
        require(
            associatedAddress != msg.sender,
            "MembershipAllowlistRegistrySecure: Cannot associate own address"
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
            revert("MembershipAllowlistRegistrySecure: Address already associated with different holder");
        }

        // SECURITY: Verify the associated address signed this association request
        uint256 currentNonce = nonces[associatedAddress];
        bytes32 messageHash = getAssociationMessageHash(msg.sender, associatedAddress, currentNonce);
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        require(
            recoveredSigner == associatedAddress,
            "MembershipAllowlistRegistrySecure: Invalid signature - associated address must sign"
        );

        // Increment nonce to prevent replay attacks
        nonces[associatedAddress]++;

        // Create association
        associatedToMembership[associatedAddress] = msg.sender;
        membershipAssociatedCount[msg.sender]++;

        emit AssociatedAddressAdded(msg.sender, associatedAddress);
    }

    /**
     * @notice Generate the message hash that the associated address must sign
     * @dev Includes chainId and contract address to prevent cross-chain/cross-contract replay
     *
     * @param membershipHolder The membership holder who will register the association
     * @param associatedAddress The address being associated
     * @param nonce The current nonce for the associated address
     * @return The message hash to be signed
     */
    function getAssociationMessageHash(
        address membershipHolder,
        address associatedAddress,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "Associate address with CryptoArt membership:",
                membershipHolder,
                associatedAddress,
                nonce,
                block.chainid,
                address(this)
            )
        );
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
            "MembershipAllowlistRegistrySecure: Address not associated"
        );

        // Check if caller is the membership holder who registered this address
        require(
            membershipHolder == msg.sender,
            "MembershipAllowlistRegistrySecure: Only membership holder can remove"
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
     * @notice Allows an associated address to remove their own association
     * @dev Callable by the associated address themselves - gives them control to revoke
     */
    function removeSelfAssociation() external {
        address membershipHolder = associatedToMembership[msg.sender];

        // Check if caller has an association
        require(
            membershipHolder != address(0),
            "MembershipAllowlistRegistrySecure: Caller not associated with any membership"
        );

        // Remove the association
        delete associatedToMembership[msg.sender];

        // Decrement counter for the membership holder
        if (membershipAssociatedCount[membershipHolder] > 0) {
            membershipAssociatedCount[membershipHolder]--;
        }

        emit AssociatedAddressRemoved(membershipHolder, msg.sender);
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






// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MembershipAllowlistRegistrySecure.sol";
import "../src/DummyERC721.sol";
import "../src/IMarketplaceSellerRegistry.sol";

/**
 * @title MembershipAllowlistRegistrySecureTest
 * @notice Comprehensive test suite for MembershipAllowlistRegistrySecure
 * @dev Tests signature-based proof of ownership for address associations
 */
contract MembershipAllowlistRegistrySecureTest is Test {
    MembershipAllowlistRegistrySecure private registry;
    DummyERC721 private membershipNFT;

    // Test addresses with private keys for signing
    uint256 private membershipHolderPK = 0x1001;
    uint256 private associatedAddress1PK = 0x1002;
    uint256 private associatedAddress2PK = 0x1003;
    uint256 private anotherMemberPK = 0x1004;
    uint256 private unauthorizedAddressPK = 0x1005;

    address private membershipHolder;
    address private associatedAddress1;
    address private associatedAddress2;
    address private anotherMember;
    address private unauthorizedAddress;

    event AssociatedAddressAdded(address indexed membershipHolder, address indexed associatedAddress);
    event AssociatedAddressRemoved(address indexed membershipHolder, address indexed associatedAddress);

    function setUp() public {
        // Derive addresses from private keys
        membershipHolder = vm.addr(membershipHolderPK);
        associatedAddress1 = vm.addr(associatedAddress1PK);
        associatedAddress2 = vm.addr(associatedAddress2PK);
        anotherMember = vm.addr(anotherMemberPK);
        unauthorizedAddress = vm.addr(unauthorizedAddressPK);

        // Deploy mock NFT contract for membership
        membershipNFT = new DummyERC721("Membership NFT", "MEMBERSHIP");

        // Deploy registry
        registry = new MembershipAllowlistRegistrySecure(address(membershipNFT));

        // Mint membership NFT to membership holder
        membershipNFT.mint(membershipHolder);

        // Mint membership NFT to another member
        membershipNFT.mint(anotherMember);
    }

    // Helper function to generate a valid signature from the associated address
    function _getAssociationSignature(
        address _membershipHolder,
        address _associatedAddress,
        uint256 _associatedAddressPK
    ) internal view returns (bytes memory) {
        uint256 nonce = registry.nonces(_associatedAddress);
        bytes32 messageHash = registry.getAssociationMessageHash(_membershipHolder, _associatedAddress, nonce);
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_associatedAddressPK, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsNFTContract() public view {
        assertEq(address(registry.getNftContract()), address(membershipNFT));
    }

    function test_Constructor_RevertsWithZeroAddress() public {
        vm.expectRevert("MembershipAllowlistRegistrySecure: Invalid NFT contract address");
        new MembershipAllowlistRegistrySecure(address(0));
    }

    // ============ isAuthorized Tests - Direct Membership ============

    function test_IsAuthorized_ReturnsTrueForDirectMembership() public view {
        bool authorized = registry.isAuthorized(membershipHolder, "");
        assertTrue(authorized, "Membership holder should be authorized");
    }

    function test_IsAuthorized_ReturnsFalseForNonMember() public view {
        bool authorized = registry.isAuthorized(unauthorizedAddress, "");
        assertFalse(authorized, "Non-member should not be authorized");
    }

    function test_IsAuthorized_ReturnsFalseAfterMembershipTransferred() public {
        // Transfer membership NFT away
        vm.prank(membershipHolder);
        membershipNFT.transferFrom(membershipHolder, unauthorizedAddress, 1);

        // Original holder should no longer be authorized
        bool authorized = registry.isAuthorized(membershipHolder, "");
        assertFalse(authorized, "Former membership holder should not be authorized");
    }

    // ============ isAuthorized Tests - Associated Addresses ============

    function test_IsAuthorized_ReturnsTrueForAssociatedAddress() public {
        // Register associated address with valid signature
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Associated address should be authorized
        bool authorized = registry.isAuthorized(associatedAddress1, "");
        assertTrue(authorized, "Associated address should be authorized");
    }

    function test_IsAuthorized_ReturnsFalseForAssociatedAddressWhenMembershipExpired() public {
        // Register associated address with valid signature
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Transfer membership away (simulating expiry/transfer)
        vm.prank(membershipHolder);
        membershipNFT.transferFrom(membershipHolder, unauthorizedAddress, 1);

        // Associated address should no longer be authorized
        bool authorized = registry.isAuthorized(associatedAddress1, "");
        assertFalse(
            authorized,
            "Associated address should not be authorized when membership expired"
        );
    }

    function test_IsAuthorized_DirectMembershipTakesPriority() public {
        // Mint NFT to associated address
        membershipNFT.mint(associatedAddress1);

        // Register as associated address with valid signature (should still work)
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Should be authorized (direct membership takes priority, but association also valid)
        bool authorized = registry.isAuthorized(associatedAddress1, "");
        assertTrue(authorized, "Address with both direct and associated membership should be authorized");
    }

    // ============ addAssociatedAddress Tests ============

    function test_AddAssociatedAddress_Success() public {
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        
        vm.prank(membershipHolder);
        vm.expectEmit(true, true, false, false);
        emit AssociatedAddressAdded(membershipHolder, associatedAddress1);

        registry.addAssociatedAddress(associatedAddress1, sig);

        // Verify association
        assertEq(
            registry.getMembershipHolder(associatedAddress1),
            membershipHolder,
            "Associated address should be mapped to membership holder"
        );
        assertEq(
            registry.membershipAssociatedCount(membershipHolder),
            1,
            "Membership holder should have 1 associated address"
        );
    }

    function test_AddAssociatedAddress_IsIdempotent() public {
        // Add first time
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Add second time (should succeed silently, skips sig check if already associated)
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Verify still only one association
        assertEq(
            registry.membershipAssociatedCount(membershipHolder),
            1,
            "Should still have only 1 associated address after duplicate add"
        );
    }

    function test_AddAssociatedAddress_RevertsIfNotMember() public {
        bytes memory sig = _getAssociationSignature(unauthorizedAddress, associatedAddress1, associatedAddress1PK);
        vm.prank(unauthorizedAddress);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Caller must hold membership");
        registry.addAssociatedAddress(associatedAddress1, sig);
    }

    function test_AddAssociatedAddress_RevertsWithZeroAddress() public {
        bytes memory sig = ""; // dummy sig, will fail before sig check
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Cannot associate zero address");
        registry.addAssociatedAddress(address(0), sig);
    }

    function test_AddAssociatedAddress_RevertsForSelf() public {
        bytes memory sig = _getAssociationSignature(membershipHolder, membershipHolder, membershipHolderPK);
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Cannot associate own address");
        registry.addAssociatedAddress(membershipHolder, sig);
    }

    function test_AddAssociatedAddress_RevertsIfAlreadyAssociatedWithDifferentHolder() public {
        // Another member associates the address first
        bytes memory sig1 = _getAssociationSignature(anotherMember, associatedAddress1, associatedAddress1PK);
        vm.prank(anotherMember);
        registry.addAssociatedAddress(associatedAddress1, sig1);

        // Try to associate with different holder - should revert
        bytes memory sig2 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Address already associated with different holder");
        registry.addAssociatedAddress(associatedAddress1, sig2);
    }

    function test_AddAssociatedAddress_CanAssociateMultipleAddresses() public {
        bytes memory sig1 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig1);

        bytes memory sig2 = _getAssociationSignature(membershipHolder, associatedAddress2, associatedAddress2PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress2, sig2);

        // Verify both associations
        assertEq(
            registry.getMembershipHolder(associatedAddress1),
            membershipHolder,
            "First associated address should be mapped"
        );
        assertEq(
            registry.getMembershipHolder(associatedAddress2),
            membershipHolder,
            "Second associated address should be mapped"
        );
        assertEq(
            registry.membershipAssociatedCount(membershipHolder),
            2,
            "Membership holder should have 2 associated addresses"
        );
    }

    function test_AddAssociatedAddress_RevertsWithInvalidSignature() public {
        // Try with a signature from the wrong address
        bytes memory wrongSig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress2PK);
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Invalid signature - associated address must sign");
        registry.addAssociatedAddress(associatedAddress1, wrongSig);
    }

    function test_AddAssociatedAddress_RevertsWithReplayedSignature() public {
        // First association works
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Remove the association
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        // Try to re-add with the same signature (should fail due to nonce increment)
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Invalid signature - associated address must sign");
        registry.addAssociatedAddress(associatedAddress1, sig);
    }

    // ============ removeAssociatedAddress Tests ============

    function test_RemoveAssociatedAddress_Success() public {
        // Add association first
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Remove association
        vm.prank(membershipHolder);
        vm.expectEmit(true, true, false, false);
        emit AssociatedAddressRemoved(membershipHolder, associatedAddress1);

        registry.removeAssociatedAddress(associatedAddress1);

        // Verify removal
        assertEq(
            registry.getMembershipHolder(associatedAddress1),
            address(0),
            "Associated address should no longer be mapped"
        );
        assertEq(
            registry.membershipAssociatedCount(membershipHolder),
            0,
            "Membership holder should have 0 associated addresses"
        );
    }

    function test_RemoveAssociatedAddress_RevertsIfNotAssociated() public {
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Address not associated");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_RevertsIfNotOwner() public {
        // Membership holder adds association
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Unauthorized address tries to remove - should revert
        vm.prank(unauthorizedAddress);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Only membership holder can remove");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_AnotherMemberCannotRemove() public {
        // Membership holder adds association
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Another member tries to remove - should revert
        vm.prank(anotherMember);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Only membership holder can remove");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_CanRemoveMultipleAddresses() public {
        // Add multiple associations
        bytes memory sig1 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig1);

        bytes memory sig2 = _getAssociationSignature(membershipHolder, associatedAddress2, associatedAddress2PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress2, sig2);

        // Remove first
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        assertEq(registry.membershipAssociatedCount(membershipHolder), 1, "Should have 1 remaining");

        // Remove second
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress2);

        assertEq(registry.membershipAssociatedCount(membershipHolder), 0, "Should have 0 remaining");
    }

    // ============ removeSelfAssociation Tests ============

    function test_RemoveSelfAssociation_Success() public {
        // Add association first
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Associated address removes their own association
        vm.prank(associatedAddress1);
        vm.expectEmit(true, true, false, false);
        emit AssociatedAddressRemoved(membershipHolder, associatedAddress1);
        registry.removeSelfAssociation();

        // Verify removal
        assertEq(
            registry.getMembershipHolder(associatedAddress1),
            address(0),
            "Associated address should no longer be mapped"
        );
    }

    function test_RemoveSelfAssociation_RevertsIfNotAssociated() public {
        vm.prank(associatedAddress1);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Caller not associated with any membership");
        registry.removeSelfAssociation();
    }

    // ============ getMembershipHolder Tests ============

    function test_GetMembershipHolder_ReturnsZeroForUnassociated() public view {
        address holder = registry.getMembershipHolder(associatedAddress1);
        assertEq(holder, address(0), "Should return zero address for unassociated address");
    }

    function test_GetMembershipHolder_ReturnsCorrectHolder() public {
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        address holder = registry.getMembershipHolder(associatedAddress1);
        assertEq(holder, membershipHolder, "Should return correct membership holder");
    }

    // ============ Edge Cases and Integration Tests ============

    function test_CompleteFlow_MembershipHolderAssociatesAndUsesAddress() public {
        // 1. Register associated address
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // 2. Verify authorization
        assertTrue(registry.isAuthorized(associatedAddress1, ""), "Should be authorized after association");

        // 3. Remove association
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        // 4. Verify no longer authorized
        assertFalse(registry.isAuthorized(associatedAddress1, ""), "Should not be authorized after removal");
    }

    function test_ReassociateAfterRemoval() public {
        // Add with first signature
        bytes memory sig1 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig1);

        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        // Can add again with new signature (nonce incremented)
        bytes memory sig2 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig2);

        assertTrue(registry.isAuthorized(associatedAddress1, ""), "Should be authorized after reassociation");
    }

    function test_MembershipLostThenRegained() public {
        // Associate address
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        // Transfer membership away
        vm.prank(membershipHolder);
        membershipNFT.transferFrom(membershipHolder, unauthorizedAddress, 1);

        // Should not be authorized
        assertFalse(registry.isAuthorized(associatedAddress1, ""), "Should not be authorized when membership lost");

        // Mint new membership to original holder
        membershipNFT.mint(membershipHolder);

        // Should be authorized again (association still exists, membership regained)
        assertTrue(registry.isAuthorized(associatedAddress1, ""), "Should be authorized when membership regained");
    }

    function test_MultipleMembers_IndependentAssociations() public {
        // First member associates address1
        bytes memory sig1 = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig1);

        // Second member associates address2
        bytes memory sig2 = _getAssociationSignature(anotherMember, associatedAddress2, associatedAddress2PK);
        vm.prank(anotherMember);
        registry.addAssociatedAddress(associatedAddress2, sig2);

        // Both should work independently
        assertTrue(registry.isAuthorized(associatedAddress1, ""), "First association should work");
        assertTrue(registry.isAuthorized(associatedAddress2, ""), "Second association should work");

        assertEq(
            registry.getMembershipHolder(associatedAddress1),
            membershipHolder,
            "First address should map to first holder"
        );
        assertEq(
            registry.getMembershipHolder(associatedAddress2),
            anotherMember,
            "Second address should map to second holder"
        );
    }

    // ============ supportsInterface Tests ============

    function test_SupportsInterface_IMarketplaceSellerRegistry() public view {
        assertTrue(
            registry.supportsInterface(type(IMarketplaceSellerRegistry).interfaceId),
            "Should support IMarketplaceSellerRegistry"
        );
    }

    function test_SupportsInterface_IERC165() public view {
        assertTrue(
            registry.supportsInterface(type(IERC165).interfaceId),
            "Should support IERC165"
        );
    }

    function test_SupportsInterface_UnknownInterface() public view {
        assertFalse(
            registry.supportsInterface(bytes4(0x12345678)),
            "Should not support unknown interface"
        );
    }

    // ============ Gas Optimization Verification ============

    function test_IsAuthorized_GasEfficient_DirectMembership() public view {
        uint256 gasBefore = gasleft();
        registry.isAuthorized(membershipHolder, "");
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 20000, "Direct membership check should be gas efficient");
    }

    function test_IsAuthorized_GasEfficient_AssociatedAddress() public {
        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        uint256 gasBefore = gasleft();
        registry.isAuthorized(associatedAddress1, "");
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 25000, "Associated address check should be gas efficient");
    }

    // ============ Nonce Tests ============

    function test_Nonce_IncreasesAfterAssociation() public {
        uint256 nonceBefore = registry.nonces(associatedAddress1);
        assertEq(nonceBefore, 0, "Initial nonce should be 0");

        bytes memory sig = _getAssociationSignature(membershipHolder, associatedAddress1, associatedAddress1PK);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1, sig);

        uint256 nonceAfter = registry.nonces(associatedAddress1);
        assertEq(nonceAfter, 1, "Nonce should be incremented after association");
    }

    function test_Nonce_PreventsCrossChainReplay() public view {
        // The message hash includes block.chainid, so signatures are chain-specific
        bytes32 messageHash = registry.getAssociationMessageHash(membershipHolder, associatedAddress1, 0);
        
        // Verify chain ID is incorporated (hash would be different on different chain)
        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                "Associate address with CryptoArt membership:",
                membershipHolder,
                associatedAddress1,
                uint256(0),
                block.chainid,
                address(registry)
            )
        );
        
        assertEq(messageHash, expectedHash, "Message hash should include chain ID");
    }

    // ============ Fuzzing Tests ============

    function testFuzz_AddAssociatedAddress_RequiresMembership(address randomAddress) public {
        vm.assume(randomAddress != address(0));
        vm.assume(randomAddress != membershipHolder);
        vm.assume(membershipNFT.balanceOf(randomAddress) == 0);

        bytes memory sig = ""; // dummy sig
        vm.prank(randomAddress);
        vm.expectRevert("MembershipAllowlistRegistrySecure: Caller must hold membership");
        registry.addAssociatedAddress(associatedAddress1, sig);
    }

    function testFuzz_IsAuthorized_NonMemberNotAuthorized(address randomAddress) public view {
        vm.assume(membershipNFT.balanceOf(randomAddress) == 0);
        vm.assume(registry.getMembershipHolder(randomAddress) == address(0));

        bool authorized = registry.isAuthorized(randomAddress, "");
        assertFalse(authorized, "Non-member should not be authorized");
    }
}






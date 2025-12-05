// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MembershipAllowlistRegistry.sol";
import "../src/DummyERC721.sol";
import "../src/IMarketplaceSellerRegistry.sol";

/**
 * @title MembershipAllowlistRegistryTest
 * @notice Comprehensive test suite for MembershipAllowlistRegistry
 */
contract MembershipAllowlistRegistryTest is Test {
    MembershipAllowlistRegistry private registry;
    DummyERC721 private membershipNFT;

    // Test addresses
    address private membershipHolder = address(0x1001);
    address private associatedAddress1 = address(0x1002);
    address private associatedAddress2 = address(0x1003);
    address private anotherMember = address(0x1004);
    address private unauthorizedAddress = address(0x1005);

    event AssociatedAddressAdded(address indexed membershipHolder, address indexed associatedAddress);
    event AssociatedAddressRemoved(address indexed membershipHolder, address indexed associatedAddress);

    function setUp() public {
        // Deploy mock NFT contract for membership
        membershipNFT = new DummyERC721("Membership NFT", "MEMBERSHIP");

        // Deploy registry
        registry = new MembershipAllowlistRegistry(address(membershipNFT));

        // Mint membership NFT to membership holder
        membershipNFT.mint(membershipHolder);

        // Mint membership NFT to another member
        membershipNFT.mint(anotherMember);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsNFTContract() public {
        assertEq(address(registry.getNftContract()), address(membershipNFT));
    }

    function test_Constructor_RevertsWithZeroAddress() public {
        vm.expectRevert("MembershipAllowlistRegistry: Invalid NFT contract address");
        new MembershipAllowlistRegistry(address(0));
    }

    // ============ isAuthorized Tests - Direct Membership ============

    function test_IsAuthorized_ReturnsTrueForDirectMembership() public {
        bool authorized = registry.isAuthorized(membershipHolder, "");
        assertTrue(authorized, "Membership holder should be authorized");
    }

    function test_IsAuthorized_ReturnsFalseForNonMember() public {
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
        // Register associated address
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Associated address should be authorized
        bool authorized = registry.isAuthorized(associatedAddress1, "");
        assertTrue(authorized, "Associated address should be authorized");
    }

    function test_IsAuthorized_ReturnsFalseForAssociatedAddressWhenMembershipExpired() public {
        // Register associated address
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

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

        // Register as associated address (should still work)
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Should be authorized (direct membership takes priority, but association also valid)
        bool authorized = registry.isAuthorized(associatedAddress1, "");
        assertTrue(authorized, "Address with both direct and associated membership should be authorized");
    }

    // ============ addAssociatedAddress Tests ============

    function test_AddAssociatedAddress_Success() public {
        vm.prank(membershipHolder);
        vm.expectEmit(true, true, false, false);
        emit AssociatedAddressAdded(membershipHolder, associatedAddress1);

        registry.addAssociatedAddress(associatedAddress1);

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
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Add second time (should succeed silently)
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Verify still only one association
        assertEq(
            registry.membershipAssociatedCount(membershipHolder),
            1,
            "Should still have only 1 associated address after duplicate add"
        );
    }

    function test_AddAssociatedAddress_RevertsIfNotMember() public {
        vm.prank(unauthorizedAddress);
        vm.expectRevert("MembershipAllowlistRegistry: Caller must hold membership");
        registry.addAssociatedAddress(associatedAddress1);
    }

    function test_AddAssociatedAddress_RevertsWithZeroAddress() public {
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistry: Cannot associate zero address");
        registry.addAssociatedAddress(address(0));
    }

    function test_AddAssociatedAddress_RevertsForSelf() public {
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistry: Cannot associate own address");
        registry.addAssociatedAddress(membershipHolder);
    }

    function test_AddAssociatedAddress_RevertsIfAlreadyAssociatedWithDifferentHolder() public {
        // Another member associates the address
        vm.prank(anotherMember);
        registry.addAssociatedAddress(associatedAddress1);

        // Try to associate with different holder - should revert
        vm.prank(membershipHolder);
        vm.expectRevert("MembershipAllowlistRegistry: Address already associated with different holder");
        registry.addAssociatedAddress(associatedAddress1);
    }

    function test_AddAssociatedAddress_CanAssociateMultipleAddresses() public {
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress2);

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

    // ============ removeAssociatedAddress Tests ============

    function test_RemoveAssociatedAddress_Success() public {
        // Add association first
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

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
        vm.expectRevert("MembershipAllowlistRegistry: Address not associated");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_RevertsIfNotOwner() public {
        // Membership holder adds association
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Unauthorized address tries to remove - should revert
        vm.prank(unauthorizedAddress);
        vm.expectRevert("MembershipAllowlistRegistry: Only membership holder can remove");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_AnotherMemberCannotRemove() public {
        // Membership holder adds association
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Another member tries to remove - should revert
        vm.prank(anotherMember);
        vm.expectRevert("MembershipAllowlistRegistry: Only membership holder can remove");
        registry.removeAssociatedAddress(associatedAddress1);
    }

    function test_RemoveAssociatedAddress_CanRemoveMultipleAddresses() public {
        // Add multiple associations
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress2);

        // Remove first
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        assertEq(registry.membershipAssociatedCount(membershipHolder), 1, "Should have 1 remaining");

        // Remove second
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress2);

        assertEq(registry.membershipAssociatedCount(membershipHolder), 0, "Should have 0 remaining");
    }

    // ============ getMembershipHolder Tests ============

    function test_GetMembershipHolder_ReturnsZeroForUnassociated() public {
        address holder = registry.getMembershipHolder(associatedAddress1);
        assertEq(holder, address(0), "Should return zero address for unassociated address");
    }

    function test_GetMembershipHolder_ReturnsCorrectHolder() public {
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        address holder = registry.getMembershipHolder(associatedAddress1);
        assertEq(holder, membershipHolder, "Should return correct membership holder");
    }

    // ============ Edge Cases and Integration Tests ============

    function test_CompleteFlow_MembershipHolderAssociatesAndUsesAddress() public {
        // 1. Register associated address
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // 2. Verify authorization
        assertTrue(registry.isAuthorized(associatedAddress1, ""), "Should be authorized after association");

        // 3. Remove association
        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        // 4. Verify no longer authorized
        assertFalse(registry.isAuthorized(associatedAddress1, ""), "Should not be authorized after removal");
    }

    function test_ReassociateAfterRemoval() public {
        // Add, remove, then add again
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        vm.prank(membershipHolder);
        registry.removeAssociatedAddress(associatedAddress1);

        // Can add again
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        assertTrue(registry.isAuthorized(associatedAddress1, ""), "Should be authorized after reassociation");
    }

    function test_MembershipLostThenRegained() public {
        // Associate address
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

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
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        // Second member associates address2
        vm.prank(anotherMember);
        registry.addAssociatedAddress(associatedAddress2);

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

    function test_SupportsInterface_IMarketplaceSellerRegistry() public {
        assertTrue(
            registry.supportsInterface(type(IMarketplaceSellerRegistry).interfaceId),
            "Should support IMarketplaceSellerRegistry"
        );
    }

    function test_SupportsInterface_IERC165() public {
        assertTrue(
            registry.supportsInterface(type(IERC165).interfaceId),
            "Should support IERC165"
        );
    }

    function test_SupportsInterface_UnknownInterface() public {
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

        // Direct membership check should be very gas efficient (< 20000 gas including test overhead)
        // Actual on-chain cost would be ~2100 gas for a single balanceOf call
        assertLt(gasUsed, 20000, "Direct membership check should be gas efficient");
    }

    function test_IsAuthorized_GasEfficient_AssociatedAddress() public {
        vm.prank(membershipHolder);
        registry.addAssociatedAddress(associatedAddress1);

        uint256 gasBefore = gasleft();
        registry.isAuthorized(associatedAddress1, "");
        uint256 gasUsed = gasBefore - gasleft();

        // Associated address check should still be efficient (< 25000 gas including test overhead)
        // Actual on-chain cost would be ~4200 gas (mapping read + 2 balanceOf calls)
        assertLt(gasUsed, 25000, "Associated address check should be gas efficient");
    }

    // ============ Fuzzing Tests ============

    function testFuzz_AddAssociatedAddress_RequiresMembership(address randomAddress) public {
        vm.assume(randomAddress != address(0));
        vm.assume(randomAddress != membershipHolder);
        vm.assume(membershipNFT.balanceOf(randomAddress) == 0);

        vm.prank(randomAddress);
        vm.expectRevert("MembershipAllowlistRegistry: Caller must hold membership");
        registry.addAssociatedAddress(associatedAddress1);
    }

    function testFuzz_IsAuthorized_NonMemberNotAuthorized(address randomAddress) public {
        vm.assume(membershipNFT.balanceOf(randomAddress) == 0);
        vm.assume(registry.getMembershipHolder(randomAddress) == address(0));

        bool authorized = registry.isAuthorized(randomAddress, "");
        assertFalse(authorized, "Non-member should not be authorized");
    }
}


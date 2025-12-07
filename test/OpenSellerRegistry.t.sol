// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/OpenSellerRegistry.sol";
import "../src/IMarketplaceSellerRegistry.sol";

/**
 * @title OpenSellerRegistryTest
 * @notice Comprehensive test suite for OpenSellerRegistry
 * @dev Tests the allow-all-by-default with blocklist functionality
 */
contract OpenSellerRegistryTest is Test {
    OpenSellerRegistry private registry;

    address private owner = address(0x1);
    address private seller1 = address(0x2);
    address private seller2 = address(0x3);
    address private seller3 = address(0x4);
    address private randomUser = address(0x5);

    event AddressBlocklisted(address indexed account);
    event AddressUnblocklisted(address indexed account);
    event SellerAdded(address requestor, address seller);
    event SellerRemoved(address requestor, address seller);

    function setUp() public {
        vm.prank(owner);
        registry = new OpenSellerRegistry(owner);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsOwner() public view {
        assertEq(registry.owner(), owner);
    }

    function test_Constructor_StartsWithNoBlocklist() public view {
        assertFalse(registry.isBlocklisted(seller1));
        assertFalse(registry.isBlocklisted(seller2));
        assertFalse(registry.isBlocklisted(randomUser));
    }

    // ============ isAuthorized Tests ============

    function test_IsAuthorized_ReturnsTrueByDefault() public view {
        assertTrue(registry.isAuthorized(seller1, ""));
        assertTrue(registry.isAuthorized(seller2, ""));
        assertTrue(registry.isAuthorized(randomUser, ""));
    }

    function test_IsAuthorized_ReturnsFalseForBlocklisted() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        assertFalse(registry.isAuthorized(seller1, ""));
        assertTrue(registry.isAuthorized(seller2, "")); // Other sellers still authorized
    }

    function test_IsAuthorized_ReturnsTrueAfterUnblocklisting() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);
        assertFalse(registry.isAuthorized(seller1, ""));

        vm.prank(owner);
        registry.removeFromBlocklist(seller1);
        assertTrue(registry.isAuthorized(seller1, ""));
    }

    // ============ addToBlocklist Tests ============

    function test_AddToBlocklist_Success() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AddressBlocklisted(seller1);
        vm.expectEmit(true, true, false, false);
        emit SellerRemoved(owner, seller1);
        
        registry.addToBlocklist(seller1);

        assertTrue(registry.isBlocklisted(seller1));
        assertFalse(registry.isAuthorized(seller1, ""));
    }

    function test_AddToBlocklist_RevertsIfNotOwner() public {
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        registry.addToBlocklist(seller1);
    }

    function test_AddToBlocklist_RevertsForZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("OpenSellerRegistry: Cannot blocklist zero address");
        registry.addToBlocklist(address(0));
    }

    function test_AddToBlocklist_RevertsIfAlreadyBlocklisted() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        vm.prank(owner);
        vm.expectRevert("OpenSellerRegistry: Already blocklisted");
        registry.addToBlocklist(seller1);
    }

    // ============ addToBlocklistBatch Tests ============

    function test_AddToBlocklistBatch_Success() public {
        address[] memory accounts = new address[](3);
        accounts[0] = seller1;
        accounts[1] = seller2;
        accounts[2] = seller3;

        vm.prank(owner);
        registry.addToBlocklistBatch(accounts);

        assertTrue(registry.isBlocklisted(seller1));
        assertTrue(registry.isBlocklisted(seller2));
        assertTrue(registry.isBlocklisted(seller3));
    }

    function test_AddToBlocklistBatch_SkipsAlreadyBlocklisted() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        address[] memory accounts = new address[](2);
        accounts[0] = seller1; // Already blocklisted
        accounts[1] = seller2; // New

        vm.prank(owner);
        registry.addToBlocklistBatch(accounts);

        assertTrue(registry.isBlocklisted(seller1));
        assertTrue(registry.isBlocklisted(seller2));
    }

    function test_AddToBlocklistBatch_RevertsIfNotOwner() public {
        address[] memory accounts = new address[](1);
        accounts[0] = seller1;

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        registry.addToBlocklistBatch(accounts);
    }

    function test_AddToBlocklistBatch_RevertsForZeroAddress() public {
        address[] memory accounts = new address[](2);
        accounts[0] = seller1;
        accounts[1] = address(0);

        vm.prank(owner);
        vm.expectRevert("OpenSellerRegistry: Cannot blocklist zero address");
        registry.addToBlocklistBatch(accounts);
    }

    // ============ removeFromBlocklist Tests ============

    function test_RemoveFromBlocklist_Success() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit AddressUnblocklisted(seller1);
        vm.expectEmit(true, true, false, false);
        emit SellerAdded(owner, seller1);
        
        registry.removeFromBlocklist(seller1);

        assertFalse(registry.isBlocklisted(seller1));
        assertTrue(registry.isAuthorized(seller1, ""));
    }

    function test_RemoveFromBlocklist_RevertsIfNotOwner() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        registry.removeFromBlocklist(seller1);
    }

    function test_RemoveFromBlocklist_RevertsIfNotBlocklisted() public {
        vm.prank(owner);
        vm.expectRevert("OpenSellerRegistry: Not blocklisted");
        registry.removeFromBlocklist(seller1);
    }

    // ============ removeFromBlocklistBatch Tests ============

    function test_RemoveFromBlocklistBatch_Success() public {
        address[] memory toAdd = new address[](3);
        toAdd[0] = seller1;
        toAdd[1] = seller2;
        toAdd[2] = seller3;

        vm.prank(owner);
        registry.addToBlocklistBatch(toAdd);

        address[] memory toRemove = new address[](2);
        toRemove[0] = seller1;
        toRemove[1] = seller2;

        vm.prank(owner);
        registry.removeFromBlocklistBatch(toRemove);

        assertFalse(registry.isBlocklisted(seller1));
        assertFalse(registry.isBlocklisted(seller2));
        assertTrue(registry.isBlocklisted(seller3)); // Not removed
    }

    function test_RemoveFromBlocklistBatch_SkipsNotBlocklisted() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        address[] memory accounts = new address[](2);
        accounts[0] = seller1; // Blocklisted
        accounts[1] = seller2; // Not blocklisted

        vm.prank(owner);
        registry.removeFromBlocklistBatch(accounts);

        assertFalse(registry.isBlocklisted(seller1));
        assertFalse(registry.isBlocklisted(seller2));
    }

    function test_RemoveFromBlocklistBatch_RevertsIfNotOwner() public {
        address[] memory accounts = new address[](1);
        accounts[0] = seller1;

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", randomUser));
        registry.removeFromBlocklistBatch(accounts);
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

    // ============ Ownership Tests ============

    function test_TransferOwnership() public {
        vm.prank(owner);
        registry.transferOwnership(randomUser);

        // New owner can blocklist
        vm.prank(randomUser);
        registry.addToBlocklist(seller1);
        assertTrue(registry.isBlocklisted(seller1));

        // Old owner cannot
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        registry.addToBlocklist(seller2);
    }

    // ============ Gas Efficiency Tests ============

    function test_IsAuthorized_GasEfficient() public view {
        uint256 gasBefore = gasleft();
        registry.isAuthorized(seller1, "");
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 15000, "isAuthorized should be gas efficient");
    }

    function test_IsAuthorized_GasEfficient_Blocklisted() public {
        vm.prank(owner);
        registry.addToBlocklist(seller1);

        uint256 gasBefore = gasleft();
        registry.isAuthorized(seller1, "");
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 15000, "isAuthorized for blocklisted should be gas efficient");
    }

    // ============ Fuzzing Tests ============

    function testFuzz_AnyAddressAuthorizedByDefault(address randomAddress) public view {
        vm.assume(randomAddress != address(0));
        assertTrue(registry.isAuthorized(randomAddress, ""), "Any address should be authorized by default");
    }

    function testFuzz_BlocklistedAddressNotAuthorized(address randomAddress) public {
        vm.assume(randomAddress != address(0));
        
        vm.prank(owner);
        registry.addToBlocklist(randomAddress);
        
        assertFalse(registry.isAuthorized(randomAddress, ""), "Blocklisted address should not be authorized");
    }

    // ============ Integration Test ============

    function test_CompleteFlow() public {
        // 1. Initially everyone is authorized
        assertTrue(registry.isAuthorized(seller1, ""));
        assertTrue(registry.isAuthorized(seller2, ""));

        // 2. Block seller1
        vm.prank(owner);
        registry.addToBlocklist(seller1);
        assertFalse(registry.isAuthorized(seller1, ""));
        assertTrue(registry.isAuthorized(seller2, ""));

        // 3. Block more addresses in batch
        address[] memory toBlock = new address[](2);
        toBlock[0] = seller2;
        toBlock[1] = seller3;
        
        vm.prank(owner);
        registry.addToBlocklistBatch(toBlock);
        assertFalse(registry.isAuthorized(seller2, ""));
        assertFalse(registry.isAuthorized(seller3, ""));

        // 4. Unblock seller1
        vm.prank(owner);
        registry.removeFromBlocklist(seller1);
        assertTrue(registry.isAuthorized(seller1, ""));

        // 5. Unblock in batch
        address[] memory toUnblock = new address[](2);
        toUnblock[0] = seller2;
        toUnblock[1] = seller3;
        
        vm.prank(owner);
        registry.removeFromBlocklistBatch(toUnblock);
        assertTrue(registry.isAuthorized(seller2, ""));
        assertTrue(registry.isAuthorized(seller3, ""));
    }
}


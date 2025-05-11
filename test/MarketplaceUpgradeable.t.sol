// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/libs/MarketplaceLib.sol";
import "../src/libs/TokenLib.sol";
import "../src/DummyERC721.sol";

contract MarketplaceUpgradeableTest is Test {
    MarketplaceUpgradeable private marketplace;
    DummyERC721 private nft;
    address private initialOwner = address(0x123); // Replace with actual initial owner address

    function setUp() public {
        // Deploy the MarketplaceUpgradeable contract
        nft = new DummyERC721("tester", "TST");

        MarketplaceUpgradeable marketplaceLogic = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable Logic deployed at:", address(marketplaceLogic));

        address proxyAddress = Upgrades.deployUUPSProxy(
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable", // Path to your contract artifact
            abi.encodeWithSelector(MarketplaceUpgradeable.initialize.selector, initialOwner)
        );

        marketplace = MarketplaceUpgradeable(proxyAddress);

    }

    function testInitialize() public view {
        assertTrue(marketplace.supportsInterface(type(IMarketplaceCore).interfaceId), "Interface not supported");
    }

    function testCreateListing() public {
        // Define the listing details
        MarketplaceLib.ListingDetails memory listingDetails = MarketplaceLib.ListingDetails({
            initialAmount: 1 ether,
            type_: MarketplaceLib.ListingType.FIXED_PRICE,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 0,
            minIncrementBPS: 0,
            erc20: address(0), // Zero address for native ETH
            identityVerifier: address(0), // No identity verification
            startTime: uint48(block.timestamp + 1 days), // Starts in 1 day
            endTime: uint48(block.timestamp + 7 days) // Ends in 7 days
        });

        MarketplaceLib.TokenDetails memory tokenDetails = MarketplaceLib.TokenDetails({
            id: 1,
            address_: address(nft),
            spec: TokenLib.Spec.ERC721,
            lazy: false
        });

        MarketplaceLib.DeliveryFees memory deliveryFees = MarketplaceLib.DeliveryFees({
            deliverBPS: 100,
            deliverFixed: 0
        });

        MarketplaceLib.ListingReceiver[] memory listingReceivers = new MarketplaceLib.ListingReceiver[](1);
        // Assuming you have a receiver contract
        listingReceivers[0] = MarketplaceLib.ListingReceiver({
            receiver: payable(address(0x138)),
            receiverBPS: 1000 // Use the correct field name from the struct definition
        });

        bool enableReferrer = false;
        bool acceptOffers = true;
        bytes memory data = "";

        vm.prank(address(0x137));
        // Call the createListing function
        uint40 listingId = marketplace.createListing(
            listingDetails,
            tokenDetails,
            deliveryFees,
            listingReceivers,
            enableReferrer,
            acceptOffers,
            data
        );

        // Assert that the listing was created successfully
        assertTrue(listingId > 0, "Listing ID should be greater than 0");
    }
} 
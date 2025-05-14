// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "lib/openzeppelin-foundry-upgrades/src/Options.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/libs/MarketplaceLib.sol";
import "../src/libs/TokenLib.sol";
import "../src/DummyERC721.sol";

contract MarketplaceUpgradeableTest is Test {
    MarketplaceUpgradeable private marketplace;
    DummyERC721 private nft;
    address private _initialOwner = address(0x123); // Replace with actual initial owner address
    address private _initialAdmin = address(0x456); // Replace with actual initial admin address
    address private _sellerRegistry = address(0x789); // Replace with actual initial seller registry address
    address private _royaltyEngine = address(0xABC); // Replace with actual initial royalty engine address



    function setUp() public {
        // Deploy the MarketplaceUpgradeable contract
        nft = new DummyERC721("tester", "TST");
        Options memory options;
        options.unsafeAllow = "external-library-linking";

        MarketplaceUpgradeable marketplaceLogic = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable Logic deployed at:", address(marketplaceLogic));
        
        address proxyAddress = Upgrades.deployUUPSProxy(
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable", // Path to your contract artifact
            abi.encodeWithSelector(MarketplaceUpgradeable.initialize.selector, _initialOwner),
            options
        );

        marketplace = MarketplaceUpgradeable(proxyAddress);


    }

    function testInitialize() public view {
        assertTrue(marketplace.supportsInterface(type(IMarketplaceCore).interfaceId), "Interface not supported");
    }

    function testAuction() public {
        hoax(address(0x10001), 1 ether);
        nft.mint(address(0x10001));

        vm.prank(address(0x10001));
        nft.approve(address(marketplace), 1);

        assertEq(nft.ownerOf(1), address(0x10001), "NFT not owned by expected address");

        // Define the listing details
        MarketplaceLib.ListingDetails memory listingDetails = MarketplaceLib.ListingDetails({
            initialAmount: 0.1 ether,
            type_: MarketplaceLib.ListingType.INDIVIDUAL_AUCTION,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 0,
            minIncrementBPS: 0,
            erc20: address(0), // Zero address for native ETH
            identityVerifier: address(0), // No identity verification
            startTime: uint48(0),
            endTime: uint48(block.timestamp + 1 hours) // Ends in 7 days
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
            receiver: payable(address(0x10001)),
            receiverBPS: 10000 // Use the correct field name from the struct definition
        });

        bool enableReferrer = false;
        bool acceptOffers = true;
        bytes memory data = "";

        vm.prank(address(0x10001));
        uint40 listingId = marketplace.createListing(
            listingDetails,
            tokenDetails,
            deliveryFees,
            listingReceivers,
            enableReferrer,
            acceptOffers,
            data
        );
        assertTrue(listingId > 0, "Listing ID should be greater than 0");


        deal(address(0x10002), 1 ether);
        vm.prank(address(0x10002));
        marketplace.bid{value:0.15 ether}(
            listingId,
            false
        );
        assertEq(
            marketplace.getListing(listingId).bid.bidder,
            address(0x10002),
            "Highest bidder should be 0x10002"
        );

        vm.warp(block.timestamp + 2 hours);
        deal(address(0x10002), 1 ether);
        vm.prank(address(0x10001));
        //ERROR is thrown from the line below:
        marketplace.finalize(listingId);
        assertEq( nft.ownerOf(1), address(0x10002), "NFT should be owned by the highest bidder");
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/MembershipSellerRegistry.sol";
import "../src/DummyERC721.sol";
import "../src/libs/MarketplaceLib.sol";
import { Upgrades } from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "@openzeppelin-foundry-upgrades/Options.sol";

/**
 * @title TestMarketplaceLocal
 * @notice Local test script for testing marketplace functionality on Anvil
 * - Deploys contracts locally
 * - Creates auctions
 * - Places bids
 * - Buy-now (fixed price) purchases
 * 
 * Uses Anvil's default accounts:
 * - Account 0: Deployer (has NFTs)
 * - Account 1: Seller
 * - Account 2: Buyer/Bidder
 */
contract TestMarketplaceLocal is Script {
    // Test wallets (Anvil default accounts)
    address constant WALLET_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Deployer
    address constant WALLET_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Seller
    address constant WALLET_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Buyer

    MarketplaceUpgradeable marketplace;
    DummyERC721 mockNFT;
    MembershipSellerRegistry sellerRegistry;

    uint256 public tokenId1;
    uint256 public tokenId2;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==========================================");
        console.log("Local Marketplace Test Script");
        console.log("==========================================");
        console.log("Wallet 0 (Deployer):", WALLET_0);
        console.log("Wallet 1 (Seller):", WALLET_1);
        console.log("Wallet 2 (Buyer):", WALLET_2);
        console.log("==========================================");

        vm.startBroadcast(deployerKey);

        // Deploy contracts
        console.log("\n=== Step 0: Deploy Contracts ===");
        deployContracts();

        // Switch to wallet1 (seller)
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_1"));

        console.log("\n=== Step 1: Mint NFTs to Seller ===");
        testMintNFTs();

        console.log("\n=== Step 2: Create Fixed Price Listing ===");
        uint40 fixedPriceListingId = testCreateFixedPriceListing();

        // Switch to wallet2 (buyer)
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_2"));

        console.log("\n=== Step 3: Purchase Fixed Price Listing ===");
        testPurchaseFixedPrice(fixedPriceListingId);

        // Switch back to wallet1 (seller) for auction
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_1"));

        console.log("\n=== Step 4: Create Auction Listing ===");
        uint40 auctionListingId = testCreateAuctionListing();

        // Switch to wallet2 (bidder)
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_2"));

        console.log("\n=== Step 5: Place Bids on Auction ===");
        testPlaceBids(auctionListingId);

        // Switch to wallet0 (another bidder)
        vm.stopBroadcast();
        vm.startBroadcast(deployerKey);

        console.log("\n=== Step 6: Place Higher Bid ===");
        testPlaceHigherBid(auctionListingId);

        // Switch back to wallet1 (seller) to finalize
        vm.stopBroadcast();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY_1"));

        console.log("\n=== Step 7: Finalize Auction ===");
        testFinalizeAuction(auctionListingId);

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("All Tests Completed Successfully!");
        console.log("==========================================");
    }

    function deployContracts() internal {
        // Deploy mock NFT
        mockNFT = new DummyERC721("Test NFT", "TEST");
        console.log("Mock NFT deployed at:", address(mockNFT));

        // Deploy seller registry
        sellerRegistry = new MembershipSellerRegistry(address(mockNFT));
        console.log("Seller Registry deployed at:", address(sellerRegistry));

        // Deploy marketplace logic
        MarketplaceUpgradeable marketplaceLogic = new MarketplaceUpgradeable();
        console.log("Marketplace Logic deployed at:", address(marketplaceLogic));

        // Deploy marketplace proxy
        Options memory options;
        options.unsafeAllow = "external-library-linking";
        address proxyAddress = Upgrades.deployUUPSProxy(
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable",
            abi.encodeWithSelector(MarketplaceUpgradeable.initialize.selector, WALLET_0),
            options
        );
        marketplace = MarketplaceUpgradeable(payable(proxyAddress));
        console.log("Marketplace Proxy deployed at:", address(marketplace));

        // Configure seller registry
        marketplace.setSellerRegistry(address(sellerRegistry));
        console.log("Seller registry configured");
    }

    function testMintNFTs() internal {
        // Get current balance to determine starting token ID
        uint256 balanceBefore = mockNFT.balanceOf(WALLET_1);
        
        // Mint NFT to wallet1 (seller)
        mockNFT.mint(WALLET_1);
        uint256 balanceAfter1 = mockNFT.balanceOf(WALLET_1);
        tokenId1 = balanceBefore + 1; // DummyERC721 starts from 1
        console.log("Minted NFT to wallet1, token ID:", tokenId1);
        console.log("Balance:", balanceAfter1);

        // Mint another NFT to wallet1
        mockNFT.mint(WALLET_1);
        uint256 balanceAfter2 = mockNFT.balanceOf(WALLET_1);
        tokenId2 = balanceAfter1 + 1;
        console.log("Minted second NFT to wallet1, token ID:", tokenId2);
        console.log("Balance:", balanceAfter2);

        // Verify seller is authorized (has NFTs)
        bool isAuthorized = sellerRegistry.isAuthorized(WALLET_1, "");
        console.log("Wallet1 authorized to sell:", isAuthorized);
        require(isAuthorized, "Seller must be authorized");
    }

    function testCreateFixedPriceListing() internal returns (uint40 listingId) {
        // Use the first minted token
        uint256 tokenId = tokenId1;

        // Approve marketplace to transfer NFT
        mockNFT.approve(address(marketplace), tokenId);
        console.log("Approved marketplace to transfer token", tokenId);

        // Create fixed price listing
        MarketplaceLib.ListingDetails memory listingDetails = MarketplaceLib.ListingDetails({
            initialAmount: 0.01 ether, // 0.01 ETH
            type_: MarketplaceLib.ListingType.FIXED_PRICE,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 0,
            minIncrementBPS: 0,
            erc20: address(0), // ETH
            identityVerifier: address(0),
            startTime: uint48(block.timestamp), // Start immediately
            endTime: uint48(block.timestamp + 7 days) // End in 7 days
        });

        MarketplaceLib.TokenDetails memory tokenDetails = MarketplaceLib.TokenDetails({
            id: tokenId,
            address_: address(mockNFT),
            spec: TokenLib.Spec.ERC721,
            lazy: false
        });

        MarketplaceLib.DeliveryFees memory deliveryFees = MarketplaceLib.DeliveryFees({
            deliverBPS: 0,
            deliverFixed: 0
        });

        listingId = marketplace.createListing(
            listingDetails,
            tokenDetails,
            deliveryFees,
            new MarketplaceLib.ListingReceiver[](0), // No receivers
            false, // enableReferrer
            false, // acceptOffers
            "" // data
        );

        console.log("Created fixed price listing ID:", uint256(listingId));
        console.log("Price: 0.01 ETH");
        console.log("Token ID:", tokenId);

        // Verify listing
        IMarketplaceCore.Listing memory listing = marketplace.getListing(listingId);
        console.log("Listing seller:", listing.seller);
        console.log("Listing price:", listing.details.initialAmount);
        console.log("Listing type:", uint8(listing.details.type_));

        return listingId;
    }

    function testPurchaseFixedPrice(uint40 listingId) internal {
        // Get listing price
        uint256 price = marketplace.getListingCurrentPrice(listingId);
        console.log("Listing price:", price);

        // Purchase the listing
        marketplace.purchase{value: price}(listingId);
        console.log("Purchased listing", uint256(listingId));

        // Verify NFT was transferred
        IMarketplaceCore.Listing memory listing = marketplace.getListing(listingId);
        console.log("NFT owner after purchase:", mockNFT.ownerOf(listing.token.id));
        console.log("Total sold:", listing.totalSold);
    }

    function testCreateAuctionListing() internal returns (uint40 listingId) {
        // Use the second minted token
        uint256 tokenId = tokenId2;

        // Approve marketplace to transfer NFT
        mockNFT.approve(address(marketplace), tokenId);
        console.log("Approved marketplace to transfer token", tokenId);

        // Create auction listing
        MarketplaceLib.ListingDetails memory listingDetails = MarketplaceLib.ListingDetails({
            initialAmount: 0.005 ether, // Reserve price: 0.005 ETH
            type_: MarketplaceLib.ListingType.INDIVIDUAL_AUCTION,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 300, // 5 minutes extension
            minIncrementBPS: 500, // 5% minimum increment
            erc20: address(0), // ETH
            identityVerifier: address(0),
            startTime: uint48(block.timestamp), // Start immediately
            endTime: uint48(block.timestamp + 1 hours) // End in 1 hour
        });

        MarketplaceLib.TokenDetails memory tokenDetails = MarketplaceLib.TokenDetails({
            id: tokenId,
            address_: address(mockNFT),
            spec: TokenLib.Spec.ERC721,
            lazy: false
        });

        MarketplaceLib.DeliveryFees memory deliveryFees = MarketplaceLib.DeliveryFees({
            deliverBPS: 0,
            deliverFixed: 0
        });

        listingId = marketplace.createListing(
            listingDetails,
            tokenDetails,
            deliveryFees,
            new MarketplaceLib.ListingReceiver[](0),
            false, // enableReferrer
            false, // acceptOffers
            "" // data
        );

        console.log("Created auction listing ID:", uint256(listingId));
        console.log("Reserve price: 0.005 ETH");
        console.log("End time:", listingDetails.endTime);
        console.log("Token ID:", tokenId);

        return listingId;
    }

    function testPlaceBids(uint40 listingId) internal {
        // Get reserve price
        uint256 reservePrice = marketplace.getListingCurrentPrice(listingId);
        console.log("Reserve price:", reservePrice);

        // Place initial bid (at reserve price)
        marketplace.bid{value: reservePrice}(listingId, false);
        console.log("Placed initial bid:", reservePrice);

        // Check bid
        MarketplaceLib.Bid[] memory bids = marketplace.getBids(listingId);
        require(bids.length > 0, "Bid should exist");
        console.log("Current bid amount:", bids[0].amount);
        console.log("Current bidder:", bids[0].bidder);
    }

    function testPlaceHigherBid(uint40 listingId) internal {
        // Get current listing
        IMarketplaceCore.Listing memory listing = marketplace.getListing(listingId);
        require(listing.bid.amount > 0, "Should have existing bid");

        // Calculate minimum bid (current bid + 5% increment)
        uint256 currentBid = listing.bid.amount;
        uint256 minIncrement = (currentBid * listing.details.minIncrementBPS) / 10000;
        uint256 newBidAmount = currentBid + minIncrement;
        
        console.log("Current bid:", currentBid);
        console.log("Minimum increment:", minIncrement);
        console.log("Placing bid:", newBidAmount);

        // Place higher bid
        marketplace.bid{value: newBidAmount}(listingId, false);
        console.log("Placed higher bid:", newBidAmount);

        // Verify bid
        MarketplaceLib.Bid[] memory bids = marketplace.getBids(listingId);
        require(bids.length > 0, "Bid should exist");
        console.log("New bid amount:", bids[0].amount);
        console.log("New bidder:", bids[0].bidder);
    }

    function testFinalizeAuction(uint40 listingId) internal {
        // Fast forward time to after auction end
        IMarketplaceCore.Listing memory listing = marketplace.getListing(listingId);
        uint48 endTime = listing.details.endTime;
        
        console.log("Current time:", block.timestamp);
        console.log("Auction end time:", endTime);
        
        if (block.timestamp < endTime) {
            console.log("Fast forwarding to after auction end...");
            vm.warp(endTime + 1);
        }

        // Finalize the auction
        marketplace.finalize(listingId);
        console.log("Finalized auction listing", uint256(listingId));

        // Verify finalization
        listing = marketplace.getListing(listingId);
        console.log("Listing finalized:", listing.finalized);
        console.log("Total sold:", listing.totalSold);
        console.log("Bid settled:", listing.bid.settled);
        
        // Verify NFT was transferred to winning bidder
        console.log("NFT owner after finalization:", mockNFT.ownerOf(listing.token.id));
    }
}


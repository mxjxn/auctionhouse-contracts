// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/MembershipSellerRegistry.sol";
import "../src/DummyERC721.sol";
import "../src/libs/MarketplaceLib.sol";

/**
 * @title TestMarketplace
 * @notice Test script for testing marketplace functionality on testnet.
 * 
 * Since testnets have real time constraints, tests are split into phases:
 * 
 * Phase 1 (run first): CreateListings
 *   forge script script/TestMarketplace.s.sol:CreateListings --rpc-url $RPC_URL --broadcast -vvv
 * 
 * Phase 2 (wait 2+ minutes, then run): PurchaseAndBid  
 *   LISTING_ID=1 AUCTION_ID=2 forge script script/TestMarketplace.s.sol:PurchaseAndBid --rpc-url $RPC_URL --broadcast -vvv
 * 
 * Phase 3 (after auction ends): FinalizeAuction
 *   AUCTION_ID=2 forge script script/TestMarketplace.s.sol:FinalizeAuction --rpc-url $RPC_URL --broadcast -vvv
 * 
 * Uses mnemonic to derive test wallets:
 * - Index 0: Wallet 1 (Seller)
 * - Index 1: Wallet 2 (Buyer/Bidder)
 * - Index 2: Wallet 3 (Deployer)
 */

// Base contract with shared configuration
abstract contract TestMarketplaceBase is Script {
    // Base Sepolia deployed addresses (Block 34297185 - Fresh Deployment)
    address constant MARKETPLACE_PROXY = 0x5336a0C2476EAdcE32C7f3C58bE809c700e4db2e;
    address constant MOCK_NFT = 0x843aE43b40c8370dFFc29fF87bE38953f8BbaAec;
    address constant SELLER_REGISTRY = 0x617753FD6Fa31E07b4A7996010D0964f001288d0;

    // Test wallets (derived from mnemonic)
    address wallet1; // Seller (index 0)
    address wallet2; // Buyer/Bidder (index 1)
    address wallet3; // Deployer (index 2)
    
    uint256 wallet1Key;
    uint256 wallet2Key;
    uint256 wallet3Key;

    MarketplaceUpgradeable marketplace;
    DummyERC721 mockNFT;
    MembershipSellerRegistry sellerRegistry;

    function setUp() public virtual {
        // Derive wallets from mnemonic
        string memory mnemonic = vm.envOr("MNEMONIC", string(""));
        require(bytes(mnemonic).length > 0, "MNEMONIC env var required for testnet");
        
        wallet1 = vm.addr(vm.deriveKey(mnemonic, 0));
        wallet2 = vm.addr(vm.deriveKey(mnemonic, 1));
        wallet3 = vm.addr(vm.deriveKey(mnemonic, 2));
        
        wallet1Key = vm.deriveKey(mnemonic, 0);
        wallet2Key = vm.deriveKey(mnemonic, 1);
        wallet3Key = vm.deriveKey(mnemonic, 2);

        // Initialize contracts
        marketplace = MarketplaceUpgradeable(payable(MARKETPLACE_PROXY));
        mockNFT = DummyERC721(MOCK_NFT);
        sellerRegistry = MembershipSellerRegistry(SELLER_REGISTRY);
    }

    function logConfig() internal view {
        console.log("==========================================");
        console.log("Wallet 1 (Seller):", wallet1);
        console.log("Wallet 2 (Buyer):", wallet2);
        console.log("Wallet 3 (Deployer):", wallet3);
        console.log("Marketplace Proxy:", MARKETPLACE_PROXY);
        console.log("Mock NFT:", MOCK_NFT);
        console.log("==========================================");
    }
}

/**
 * @title CreateListings
 * @notice Phase 1: Mint NFTs and create listings
 * 
 * Run with:
 *   forge script script/TestMarketplace.s.sol:CreateListings --rpc-url $RPC_URL --broadcast -vvv
 */
contract CreateListings is TestMarketplaceBase {
    function run() external {
        console.log("==========================================");
        console.log("Phase 1: Create Listings");
        console.log("==========================================");
        logConfig();

        vm.startBroadcast(wallet1Key);

        // Step 1: Mint NFTs
        console.log("\n=== Step 1: Mint NFTs to Seller ===");
        uint256 balanceBefore = mockNFT.balanceOf(wallet1);
        
        mockNFT.mint(wallet1);
        uint256 tokenId1 = balanceBefore + 1;
        console.log("Minted NFT token ID:", tokenId1);
        
        mockNFT.mint(wallet1);
        uint256 tokenId2 = balanceBefore + 2;
        console.log("Minted NFT token ID:", tokenId2);
        console.log("New balance:", mockNFT.balanceOf(wallet1));

        // Step 2: Create Fixed Price Listing
        console.log("\n=== Step 2: Create Fixed Price Listing ===");
        mockNFT.approve(MARKETPLACE_PROXY, tokenId1);
        
        // Start 2 minutes from now to allow for broadcast delay + some buffer
        uint48 startTime = uint48(block.timestamp + 120);
        uint48 endTime = uint48(block.timestamp + 7 days);
        
        MarketplaceLib.ListingDetails memory fixedPriceDetails = MarketplaceLib.ListingDetails({
            initialAmount: 0.01 ether,
            type_: MarketplaceLib.ListingType.FIXED_PRICE,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 0,
            minIncrementBPS: 0,
            erc20: address(0),
            identityVerifier: address(0),
            startTime: startTime,
            endTime: endTime
        });

        uint40 fixedPriceId = marketplace.createListing(
            fixedPriceDetails,
            MarketplaceLib.TokenDetails({
                id: tokenId1,
                address_: MOCK_NFT,
                spec: TokenLib.Spec.ERC721,
                lazy: false
            }),
            MarketplaceLib.DeliveryFees({deliverBPS: 0, deliverFixed: 0}),
            new MarketplaceLib.ListingReceiver[](0),
            false,
            false,
            ""
        );

        console.log("Created FIXED PRICE listing ID:", uint256(fixedPriceId));
        console.log("Price: 0.01 ETH");
        console.log("Token ID:", tokenId1);
        console.log("Start time:", startTime);
        console.log("End time:", endTime);

        // Step 3: Create Auction Listing
        console.log("\n=== Step 3: Create Auction Listing ===");
        mockNFT.approve(MARKETPLACE_PROXY, tokenId2);
        
        // Auction: starts in 2 minutes, ends in 10 minutes (for quick testing)
        uint48 auctionStart = uint48(block.timestamp + 120);
        uint48 auctionEnd = uint48(block.timestamp + 600); // 10 minutes
        
        MarketplaceLib.ListingDetails memory auctionDetails = MarketplaceLib.ListingDetails({
            initialAmount: 0.005 ether,
            type_: MarketplaceLib.ListingType.INDIVIDUAL_AUCTION,
            totalAvailable: 1,
            totalPerSale: 1,
            extensionInterval: 60, // 1 minute extension
            minIncrementBPS: 500, // 5% minimum increment
            erc20: address(0),
            identityVerifier: address(0),
            startTime: auctionStart,
            endTime: auctionEnd
        });

        uint40 auctionId = marketplace.createListing(
            auctionDetails,
            MarketplaceLib.TokenDetails({
                id: tokenId2,
                address_: MOCK_NFT,
                spec: TokenLib.Spec.ERC721,
                lazy: false
            }),
            MarketplaceLib.DeliveryFees({deliverBPS: 0, deliverFixed: 0}),
            new MarketplaceLib.ListingReceiver[](0),
            false,
            false,
            ""
        );

        console.log("Created AUCTION listing ID:", uint256(auctionId));
        console.log("Reserve price: 0.005 ETH");
        console.log("Token ID:", tokenId2);
        console.log("Start time:", auctionStart);
        console.log("End time:", auctionEnd);

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("Phase 1 Complete!");
        console.log("==========================================");
        console.log("Fixed Price Listing ID:", uint256(fixedPriceId));
        console.log("Auction Listing ID:", uint256(auctionId));
        console.log("");
        console.log("NEXT: Wait 2+ minutes, then run Phase 2:");
        console.log("LISTING_ID=%s AUCTION_ID=%s forge script script/TestMarketplace.s.sol:PurchaseAndBid --rpc-url $RPC_URL --broadcast -vvv", 
            uint256(fixedPriceId), uint256(auctionId));
    }
}

/**
 * @title PurchaseAndBid
 * @notice Phase 2: Purchase fixed price listing and place bids on auction
 * 
 * Run with:
 *   LISTING_ID=1 AUCTION_ID=2 forge script script/TestMarketplace.s.sol:PurchaseAndBid --rpc-url $RPC_URL --broadcast -vvv
 */
contract PurchaseAndBid is TestMarketplaceBase {
    function run() external {
        uint40 listingId = uint40(vm.envUint("LISTING_ID"));
        uint40 auctionId = uint40(vm.envUint("AUCTION_ID"));
        
        console.log("==========================================");
        console.log("Phase 2: Purchase and Bid");
        console.log("==========================================");
        console.log("Fixed Price Listing ID:", uint256(listingId));
        console.log("Auction Listing ID:", uint256(auctionId));
        logConfig();

        // Verify listings exist and have started
        IMarketplaceCore.Listing memory fixedListing = marketplace.getListing(listingId);
        IMarketplaceCore.Listing memory auctionListing = marketplace.getListing(auctionId);
        
        console.log("\n=== Listing Status ===");
        console.log("Current time:", block.timestamp);
        console.log("Fixed price start:", fixedListing.details.startTime);
        console.log("Auction start:", auctionListing.details.startTime);
        
        require(block.timestamp >= fixedListing.details.startTime, "Fixed price listing has not started yet");
        require(block.timestamp >= auctionListing.details.startTime, "Auction has not started yet");

        // Step 1: Purchase fixed price listing as wallet2
        console.log("\n=== Step 1: Purchase Fixed Price Listing ===");
        vm.startBroadcast(wallet2Key);
        
        uint256 price = marketplace.getListingCurrentPrice(listingId);
        console.log("Price:", price);
        console.log("Buyer:", wallet2);
        
        marketplace.purchase{value: price}(listingId);
        console.log("Purchase successful!");
        
        // Verify
        fixedListing = marketplace.getListing(listingId);
        console.log("NFT owner:", mockNFT.ownerOf(fixedListing.token.id));
        console.log("Total sold:", fixedListing.totalSold);
        
        vm.stopBroadcast();

        // Step 2: Place bid on auction as wallet2
        console.log("\n=== Step 2: Place Bid on Auction (Wallet 2) ===");
        vm.startBroadcast(wallet2Key);
        
        uint256 reservePrice = marketplace.getListingCurrentPrice(auctionId);
        console.log("Reserve price:", reservePrice);
        console.log("Bidder:", wallet2);
        
        marketplace.bid{value: reservePrice}(auctionId, false);
        console.log("Bid placed successfully!");
        
        vm.stopBroadcast();

        // Step 3: Place higher bid as wallet3
        console.log("\n=== Step 3: Place Higher Bid (Wallet 3) ===");
        vm.startBroadcast(wallet3Key);
        
        auctionListing = marketplace.getListing(auctionId);
        uint256 currentBid = auctionListing.bid.amount;
        uint256 minIncrement = (currentBid * auctionListing.details.minIncrementBPS) / 10000;
        uint256 newBidAmount = currentBid + minIncrement;
        
        console.log("Current bid:", currentBid);
        console.log("Min increment (5%):", minIncrement);
        console.log("New bid amount:", newBidAmount);
        console.log("Bidder:", wallet3);
        
        marketplace.bid{value: newBidAmount}(auctionId, false);
        console.log("Higher bid placed successfully!");
        
        vm.stopBroadcast();

        // Verify final state
        auctionListing = marketplace.getListing(auctionId);
        console.log("\n=== Final Auction State ===");
        console.log("Current bid:", auctionListing.bid.amount);
        console.log("Current bidder:", auctionListing.bid.bidder);
        console.log("Auction end time:", auctionListing.details.endTime);

        console.log("\n==========================================");
        console.log("Phase 2 Complete!");
        console.log("==========================================");
        console.log("");
        console.log("NEXT: Wait for auction to end (check end time above), then run Phase 3:");
        console.log("AUCTION_ID=%s forge script script/TestMarketplace.s.sol:FinalizeAuction --rpc-url $RPC_URL --broadcast -vvv",
            uint256(auctionId));
    }
}

/**
 * @title FinalizeAuction
 * @notice Phase 3: Finalize the auction after it ends
 * 
 * Run with:
 *   AUCTION_ID=2 forge script script/TestMarketplace.s.sol:FinalizeAuction --rpc-url $RPC_URL --broadcast -vvv
 */
contract FinalizeAuction is TestMarketplaceBase {
    function run() external {
        uint40 auctionId = uint40(vm.envUint("AUCTION_ID"));
        
        console.log("==========================================");
        console.log("Phase 3: Finalize Auction");
        console.log("==========================================");
        console.log("Auction Listing ID:", uint256(auctionId));
        logConfig();

        IMarketplaceCore.Listing memory listing = marketplace.getListing(auctionId);
        
        console.log("\n=== Auction Status ===");
        console.log("Current time:", block.timestamp);
        console.log("Auction end time:", listing.details.endTime);
        console.log("Current bid:", listing.bid.amount);
        console.log("Current bidder:", listing.bid.bidder);
        console.log("Finalized:", listing.finalized);
        
        require(block.timestamp >= listing.details.endTime, "Auction has not ended yet");
        require(!listing.finalized, "Auction already finalized");

        // Finalize as the seller (wallet1)
        console.log("\n=== Finalizing Auction ===");
        vm.startBroadcast(wallet1Key);
        
        marketplace.finalize(auctionId);
        console.log("Auction finalized!");
        
        vm.stopBroadcast();

        // Verify final state
        listing = marketplace.getListing(auctionId);
        console.log("\n=== Final State ===");
        console.log("Finalized:", listing.finalized);
        console.log("Total sold:", listing.totalSold);
        console.log("Bid settled:", listing.bid.settled);
        console.log("NFT owner:", mockNFT.ownerOf(listing.token.id));
        console.log("Winning bidder:", listing.bid.bidder);

        console.log("\n==========================================");
        console.log("Phase 3 Complete! All Tests Passed!");
        console.log("==========================================");
    }
}

/**
 * @title CheckListingStatus
 * @notice Utility to check listing status without making changes
 * 
 * Run with:
 *   LISTING_ID=1 forge script script/TestMarketplace.s.sol:CheckListingStatus --rpc-url $RPC_URL -vvv
 */
contract CheckListingStatus is TestMarketplaceBase {
    function run() external view {
        uint40 listingId = uint40(vm.envUint("LISTING_ID"));
        
        console.log("==========================================");
        console.log("Listing Status Check");
        console.log("==========================================");
        console.log("Listing ID:", uint256(listingId));
        console.log("Current time:", block.timestamp);

        IMarketplaceCore.Listing memory listing = marketplace.getListing(listingId);
        
        console.log("\n=== Listing Details ===");
        console.log("Seller:", listing.seller);
        console.log("Finalized:", listing.finalized);
        console.log("Total sold:", listing.totalSold);
        console.log("Type:", uint8(listing.details.type_));
        console.log("Initial amount:", listing.details.initialAmount);
        console.log("Start time:", listing.details.startTime);
        console.log("End time:", listing.details.endTime);
        console.log("Token address:", listing.token.address_);
        console.log("Token ID:", listing.token.id);
        
        if (listing.bid.amount > 0) {
            console.log("\n=== Current Bid ===");
            console.log("Amount:", listing.bid.amount);
            console.log("Bidder:", listing.bid.bidder);
            console.log("Settled:", listing.bid.settled);
        }

        // Status checks
        console.log("\n=== Status ===");
        if (block.timestamp < listing.details.startTime) {
            console.log("Status: NOT STARTED (starts in", listing.details.startTime - block.timestamp, "seconds)");
        } else if (block.timestamp < listing.details.endTime) {
            console.log("Status: ACTIVE (ends in", listing.details.endTime - block.timestamp, "seconds)");
        } else if (!listing.finalized) {
            console.log("Status: ENDED - Ready to finalize");
        } else {
            console.log("Status: FINALIZED");
        }
    }
}

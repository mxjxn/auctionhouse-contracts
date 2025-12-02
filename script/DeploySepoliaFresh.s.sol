// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/MembershipSellerRegistry.sol";
import "../src/DummyERC721.sol";
import "../src/MockRoyaltyEngine.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySepoliaFresh is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("==========================================");
        console.log("Fresh Base Sepolia Deployment");
        console.log("==========================================");
        console.log("Owner:", initialOwner);
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        // 1. Deploy MockRoyaltyEngine
        console.log("\n1. Deploying MockRoyaltyEngine...");
        MockRoyaltyEngine mockRoyaltyEngine = new MockRoyaltyEngine();
        console.log("MockRoyaltyEngine deployed at:", address(mockRoyaltyEngine));

        // 2. Deploy mock NFT contract for seller registry
        console.log("\n2. Deploying mock NFT contract...");
        DummyERC721 mockNFT = new DummyERC721("Test NFT", "TEST");
        console.log("Mock NFT deployed at:", address(mockNFT));

        // 3. Deploy MarketplaceUpgradeable implementation
        console.log("\n3. Deploying MarketplaceUpgradeable implementation...");
        MarketplaceUpgradeable implementation = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable implementation deployed at:", address(implementation));

        // 4. Deploy ERC1967 Proxy
        console.log("\n4. Deploying ERC1967 Proxy...");
        bytes memory initData = abi.encodeWithSelector(
            MarketplaceUpgradeable.initialize.selector,
            initialOwner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("ERC1967 Proxy deployed at:", address(proxy));

        // 5. Deploy MembershipSellerRegistry
        console.log("\n5. Deploying MembershipSellerRegistry...");
        MembershipSellerRegistry sellerRegistry = new MembershipSellerRegistry(address(mockNFT));
        console.log("MembershipSellerRegistry deployed at:", address(sellerRegistry));

        // 6. Configure marketplace
        console.log("\n6. Configuring marketplace...");
        MarketplaceUpgradeable marketplace = MarketplaceUpgradeable(payable(address(proxy)));
        
        // Set seller registry
        marketplace.setSellerRegistry(address(sellerRegistry));
        console.log("Seller registry configured");
        
        // Set royalty engine
        marketplace.setRoyaltyEngineV1(address(mockRoyaltyEngine));
        console.log("MockRoyaltyEngine configured");

        vm.stopBroadcast();
        
        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("Marketplace Proxy:", address(proxy));
        console.log("Marketplace Implementation:", address(implementation));
        console.log("MockRoyaltyEngine:", address(mockRoyaltyEngine));
        console.log("Seller Registry:", address(sellerRegistry));
        console.log("Mock NFT:", address(mockNFT));
        console.log("==========================================");
    }
}


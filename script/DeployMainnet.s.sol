// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/MembershipSellerRegistry.sol";
import "../src/DummyERC721.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Deploy Mainnet
 * @notice Deploys MarketplaceUpgradeable contracts to Ethereum Mainnet
 * @dev This script:
 *      1. Deploys MarketplaceUpgradeable implementation
 *      2. Deploys ERC1967Proxy pointing to implementation
 *      3. Deploys MembershipSellerRegistry (optional, can use existing)
 *      4. Configures marketplace with Manifold Royalty Engine V1
 * 
 * Required environment variables:
 *      - PRIVATE_KEY: Deployer private key
 *      - OWNER: Address that will own the marketplace (defaults to deployer)
 *      - MEMBERSHIP_NFT: Address of membership NFT contract (optional, will deploy mock if not set)
 *      - ROYALTY_ENGINE: Manifold Royalty Engine V1 address (defaults to mainnet address)
 * 
 * Usage:
 *      # Simulate deployment (estimate gas)
 *      forge script script/DeployMainnet.s.sol:DeployMainnet \
 *        --rpc-url $ETH_RPC_URL \
 *        --private-key $PRIVATE_KEY \
 *        -vvv
 * 
 *      # Actually deploy
 *      forge script script/DeployMainnet.s.sol:DeployMainnet \
 *        --rpc-url $ETH_RPC_URL \
 *        --private-key $PRIVATE_KEY \
 *        --broadcast \
 *        --verify \
 *        -vvv
 */
contract DeployMainnet is Script {
    // Manifold Royalty Engine V1 on Ethereum Mainnet
    // Source: https://royaltyregistry.xyz
    address constant MANIFOLD_ROYALTY_ENGINE_MAINNET = 0x0385603ab55642cb4Dd5De3aE9e306809991804f;
    
    // Manifold Royalty Registry on Ethereum Mainnet
    address constant MANIFOLD_ROYALTY_REGISTRY_MAINNET = 0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D;

    struct DeploymentInfo {
        address marketplaceImplementation;
        address marketplaceProxy;
        address sellerRegistry;
        address membershipNFT;
        address royaltyEngine;
        address owner;
        uint256 chainId;
    }

    function run() external {
        // Verify we're on Ethereum mainnet
        require(block.chainid == 1, "This script is for Ethereum Mainnet only (chainId: 1)");
        
        // Read configuration from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address initialOwner = vm.envOr("OWNER", deployer);
        
        // Optional: Use existing membership NFT or deploy mock
        address membershipNFT = vm.envOr("MEMBERSHIP_NFT", address(0));
        bool deployMockNFT = membershipNFT == address(0);
        
        // Use Manifold Royalty Engine on mainnet (can be overridden)
        address royaltyEngine = vm.envOr("ROYALTY_ENGINE", MANIFOLD_ROYALTY_ENGINE_MAINNET);
        
        console.log("==========================================");
        console.log("Deploying Auctionhouse Contracts to Ethereum Mainnet");
        console.log("==========================================");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("Owner:", initialOwner);
        console.log("Royalty Engine:", royaltyEngine);
        console.log("Royalty Registry:", MANIFOLD_ROYALTY_REGISTRY_MAINNET);
        console.log("==========================================");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy mock NFT if needed
        address finalMembershipNFT = membershipNFT;
        if (deployMockNFT) {
            console.log("\n1. Deploying mock NFT contract...");
            DummyERC721 mockNFT = new DummyERC721("Cryptoart Membership", "CRYPTOART");
            finalMembershipNFT = address(mockNFT);
            console.log("Mock NFT deployed at:", finalMembershipNFT);
        } else {
            console.log("\n1. Using existing membership NFT:", finalMembershipNFT);
        }

        // 2. Deploy MarketplaceUpgradeable implementation
        console.log("\n2. Deploying MarketplaceUpgradeable implementation...");
        MarketplaceUpgradeable implementation = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable implementation deployed at:", address(implementation));

        // 3. Deploy ERC1967 Proxy
        console.log("\n3. Deploying ERC1967 Proxy...");
        bytes memory initData = abi.encodeWithSelector(
            MarketplaceUpgradeable.initialize.selector,
            initialOwner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("ERC1967 Proxy deployed at:", address(proxy));

        // 4. Deploy MembershipSellerRegistry
        console.log("\n4. Deploying MembershipSellerRegistry...");
        MembershipSellerRegistry sellerRegistry = new MembershipSellerRegistry(finalMembershipNFT);
        console.log("MembershipSellerRegistry deployed at:", address(sellerRegistry));

        // 5. Configure marketplace
        console.log("\n5. Configuring marketplace...");
        MarketplaceUpgradeable marketplace = MarketplaceUpgradeable(payable(address(proxy)));
        
        // Set seller registry
        marketplace.setSellerRegistry(address(sellerRegistry));
        console.log("Seller registry configured:", address(sellerRegistry));
        
        // Set royalty engine (Manifold Royalty Engine V1)
        marketplace.setRoyaltyEngineV1(royaltyEngine);
        console.log("Royalty Engine configured:", royaltyEngine);

        vm.stopBroadcast();

        // Save deployment info
        DeploymentInfo memory info = DeploymentInfo({
            marketplaceImplementation: address(implementation),
            marketplaceProxy: address(proxy),
            sellerRegistry: address(sellerRegistry),
            membershipNFT: finalMembershipNFT,
            royaltyEngine: royaltyEngine,
            owner: initialOwner,
            chainId: block.chainid
        });

        _saveDeploymentInfo(info);

        // Summary
        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("Marketplace Proxy (USE THIS):", address(proxy));
        console.log("Marketplace Implementation:", address(implementation));
        console.log("Seller Registry:", address(sellerRegistry));
        console.log("Membership NFT:", finalMembershipNFT);
        console.log("Royalty Engine:", royaltyEngine);
        console.log("Owner:", initialOwner);
        console.log("==========================================");
    }

    function _saveDeploymentInfo(DeploymentInfo memory info) internal {
        string memory json = string.concat(
            "{\n",
            "  \"chainId\": ", vm.toString(info.chainId), ",\n",
            "  \"owner\": \"", vm.toString(info.owner), "\",\n",
            "  \"royaltyEngine\": \"", vm.toString(info.royaltyEngine), "\",\n",
            "  \"royaltyRegistry\": \"", vm.toString(MANIFOLD_ROYALTY_REGISTRY_MAINNET), "\",\n",
            "  \"contracts\": {\n",
            "    \"marketplaceProxy\": \"", vm.toString(info.marketplaceProxy), "\",\n",
            "    \"marketplaceImplementation\": \"", vm.toString(info.marketplaceImplementation), "\",\n",
            "    \"sellerRegistry\": \"", vm.toString(info.sellerRegistry), "\",\n",
            "    \"membershipNFT\": \"", vm.toString(info.membershipNFT), "\"\n",
            "  }\n",
            "}\n"
        );

        string memory filename = string.concat("deployments/deployment-mainnet-", vm.toString(block.timestamp), ".json");
        vm.writeFile(filename, json);
        console.log("\nDeployment info saved to:", filename);
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { Upgrades } from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "@openzeppelin-foundry-upgrades/Options.sol";
import "../src/MarketplaceUpgradeable.sol";
import "../src/MembershipSellerRegistry.sol";
import "../src/DummyERC721.sol";

contract DeployContracts is Script {
    struct DeploymentInfo {
        address mockNFT;
        address marketplaceLogic;
        address marketplaceProxy;
        address sellerRegistry;
        address owner;
        uint256 chainId;
    }

    function run() external {
        // Read configuration from environment variables
        address initialOwner = vm.envOr("OWNER", msg.sender);
        string memory mockNFTName = vm.envOr("MOCK_NFT_NAME", string("Cryptoart Membership"));
        string memory mockNFTSymbol = vm.envOr("MOCK_NFT_SYMBOL", string("CRYPTOART"));

        // Derive private key from mnemonic if provided, otherwise use PRIVATE_KEY
        uint256 deployerPrivateKey;
        address derivedAddress;
        
        try vm.envString("MNEMONIC") returns (string memory mnemonic) {
            uint32 mnemonicIndex = uint32(vm.envOr("MNEMONIC_INDEX", uint256(0)));
            deployerPrivateKey = vm.deriveKey(mnemonic, mnemonicIndex);
            derivedAddress = vm.addr(deployerPrivateKey);
            console.log("Derived private key from mnemonic");
            console.log("Mnemonic index:", vm.toString(mnemonicIndex));
            console.log("Derived address:", derivedAddress);
        } catch {
            deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            derivedAddress = vm.addr(deployerPrivateKey);
        }
        
        vm.startBroadcast(deployerPrivateKey);

        console.log("==========================================");
        console.log("Deploying Auctionhouse Contracts");
        console.log("==========================================");
        console.log("Owner:", initialOwner);
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        // 1. Deploy mock NFT contract for seller registry
        console.log("\n1. Deploying mock NFT contract...");
        DummyERC721 mockNFT = new DummyERC721(mockNFTName, mockNFTSymbol);
        console.log("Mock NFT deployed at:", address(mockNFT));

        // 2. Deploy MarketplaceUpgradeable logic contract
        console.log("\n2. Deploying MarketplaceUpgradeable logic contract...");
        MarketplaceUpgradeable marketplaceLogic = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable Logic deployed at:", address(marketplaceLogic));

        // 3. Deploy the proxy contract
        console.log("\n3. Deploying MarketplaceUpgradeable proxy...");
        Options memory options;
        options.unsafeAllow = "external-library-linking";
        address proxyAddress = Upgrades.deployUUPSProxy(
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable",
            abi.encodeWithSelector(MarketplaceUpgradeable.initialize.selector, initialOwner),
            options
        );
        console.log("MarketplaceUpgradeable Proxy deployed at:", proxyAddress);

        // 4. Deploy MembershipSellerRegistry
        console.log("\n4. Deploying MembershipSellerRegistry...");
        MembershipSellerRegistry sellerRegistry = new MembershipSellerRegistry(address(mockNFT));
        console.log("MembershipSellerRegistry deployed at:", address(sellerRegistry));

        // 5. Set the seller registry in the MarketplaceUpgradeable contract
        console.log("\n5. Configuring marketplace...");
        MarketplaceUpgradeable marketplaceAtProxy = MarketplaceUpgradeable(proxyAddress);
        marketplaceAtProxy.setSellerRegistry(address(sellerRegistry));
        console.log("Seller registry set in MarketplaceUpgradeable");

        // Save deployment info
        DeploymentInfo memory info = DeploymentInfo({
            mockNFT: address(mockNFT),
            marketplaceLogic: address(marketplaceLogic),
            marketplaceProxy: proxyAddress,
            sellerRegistry: address(sellerRegistry),
            owner: initialOwner,
            chainId: block.chainid
        });

        _saveDeploymentInfo(info);

        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("Mock NFT:", address(mockNFT));
        console.log("Marketplace Logic:", address(marketplaceLogic));
        console.log("Marketplace Proxy:", proxyAddress);
        console.log("Seller Registry:", address(sellerRegistry));
        console.log("Owner:", initialOwner);
        console.log("==========================================");

        vm.stopBroadcast();
    }

    function _saveDeploymentInfo(DeploymentInfo memory info) internal {
        string memory json = string.concat(
            "{\n",
            '  "chainId": ', vm.toString(info.chainId), ",\n",
            '  "owner": "', vm.toString(info.owner), '",\n",
            '  "contracts": {\n',
            '    "mockNFT": "', vm.toString(info.mockNFT), '",\n',
            '    "marketplaceLogic": "', vm.toString(info.marketplaceLogic), '",\n',
            '    "marketplaceProxy": "', vm.toString(info.marketplaceProxy), '",\n',
            '    "sellerRegistry": "', vm.toString(info.sellerRegistry), '"\n',
            "  }\n",
            "}\n"
        );

        string memory filename = string.concat("deployments/deployment-", vm.toString(block.chainid), ".json");
        vm.writeFile(filename, json);
        console.log("\nDeployment info saved to:", filename);
    }
}
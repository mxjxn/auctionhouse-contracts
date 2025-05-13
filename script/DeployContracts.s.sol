// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol"; // Adjust path as needed
import { Options } from "openzeppelin-foundry-upgrades/Options.sol"; // Adjust path as needed
import "../src/MarketplaceUpgradeable.sol"; // Your implementation contract
import "../src/MembershipSellerRegistry.sol"; // Assuming the path to the MembershipSellerRegistry contract

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();

        address initialOwner = msg.sender; // Or your desired owner

        // Deploy MarketplaceUpgradeable logic contract (often handled by the Upgrades library,
        // or you deploy it first and then pass its address)
        // For UUPS, you'd typically deploy the implementation first, then the proxy.
        // For Transparent, the library might deploy both.

        // Example using a hypothetical UUPS deployment function from such a library
        // The actual function and parameters might differ.
        // It would deploy the logic, then the proxy, and call initialize.

        // 1. Deploy the logic contract
        MarketplaceUpgradeable marketplaceLogic = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable Logic deployed at:", address(marketplaceLogic));
        // 2. Deploy the proxy contract
        Options memory options;
        options.unsafeAllow = "external-library-linking";
        address proxyAddress = Upgrades.deployUUPSProxy(
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable", // Path to your contract artifact
            abi.encodeWithSelector(MarketplaceUpgradeable.initialize.selector, initialOwner), 
            options
        );

        console.log("MarketplaceUpgradeable Proxy deployed at:", proxyAddress);

        // Deploy MembershipSellerRegistry, 
        // which uses cryptoart hypersub's time-balance as a seller registry
        address nftContractAddress = 0x4b212e795b74a36B4CCf744Fc2272B34eC2e9d90;
        MembershipSellerRegistry sellerRegistry = new MembershipSellerRegistry(nftContractAddress);
        console.log("MembershipSellerRegistry deployed at:", address(sellerRegistry));


        // Set the seller registry in the MarketplaceUpgradeable contract
        MarketplaceUpgradeable marketplaceAtProxy = MarketplaceUpgradeable(proxyAddress);
        marketplaceAtProxy.setSellerRegistry(address(sellerRegistry));
        console.log("Seller registry set in MarketplaceUpgradeable");

        vm.stopBroadcast();
    }
}
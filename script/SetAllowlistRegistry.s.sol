// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MarketplaceUpgradeable.sol";

/**
 * @title SetAllowlistRegistry
 * @notice Script to set MembershipAllowlistRegistry as the seller registry in the marketplace
 * @dev Requires admin access to the marketplace
 */
contract SetAllowlistRegistry is Script {
    function run() external {
        // Read configuration from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Marketplace proxy address (Base Mainnet)
        address marketplaceProxy = vm.envOr(
            "MARKETPLACE_PROXY",
            address(0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9)
        );
        
        // MembershipAllowlistRegistry address (deployed in Step 1)
        address allowlistRegistry = vm.envOr(
            "ALLOWLIST_REGISTRY",
            address(0xF190fD214844931a92076aeCB5316f769f4A8483)
        );

        vm.startBroadcast(deployerPrivateKey);

        console.log("==========================================");
        console.log("Setting MembershipAllowlistRegistry");
        console.log("==========================================");
        console.log("Marketplace Proxy:", marketplaceProxy);
        console.log("Allowlist Registry:", allowlistRegistry);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        // Set the new seller registry
        MarketplaceUpgradeable marketplace = MarketplaceUpgradeable(payable(marketplaceProxy));
        
        console.log("\nSetting seller registry to MembershipAllowlistRegistry...");
        marketplace.setSellerRegistry(allowlistRegistry);
        console.log("[OK] Seller registry updated!");

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("Configuration Complete!");
        console.log("==========================================");
        console.log("Marketplace Proxy:", marketplaceProxy);
        console.log("Seller Registry:", allowlistRegistry);
        console.log("==========================================");
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/OpenSellerRegistry.sol";

/**
 * @title DeployOpenSellerRegistry
 * @notice Script to deploy OpenSellerRegistry
 * @dev Run with: forge script script/DeployOpenSellerRegistry.s.sol --rpc-url $RPC_URL --broadcast --verify
 */
contract DeployOpenSellerRegistry is Script {
    function run() external {
        // Read configuration from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Owner defaults to deployer, can be overridden
        address owner = vm.envOr("REGISTRY_OWNER", deployer);

        console.log("==========================================");
        console.log("Deploying OpenSellerRegistry");
        console.log("==========================================");
        console.log("Deployer:", deployer);
        console.log("Registry Owner:", owner);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy OpenSellerRegistry
        OpenSellerRegistry registry = new OpenSellerRegistry(owner);
        console.log("\n[OK] OpenSellerRegistry deployed at:", address(registry));

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("OpenSellerRegistry:", address(registry));
        console.log("Owner:", owner);
        console.log("\nNext steps:");
        console.log("1. Verify the contract on block explorer");
        console.log("2. Set as seller registry on marketplace using:");
        console.log("   cast send <MARKETPLACE_PROXY> 'setSellerRegistry(address)' <REGISTRY_ADDRESS>");
        console.log("==========================================");
    }
}


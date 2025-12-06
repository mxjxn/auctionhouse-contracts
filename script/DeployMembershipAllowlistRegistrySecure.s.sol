// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MembershipAllowlistRegistrySecure.sol";

/**
 * @title DeployMembershipAllowlistRegistrySecure
 * @notice Deployment script for the secure version of MembershipAllowlistRegistry
 * @dev Deploys to Base Mainnet or Base Sepolia depending on environment
 * 
 * Usage:
 *   Base Mainnet:
 *     forge script script/DeployMembershipAllowlistRegistrySecure.s.sol:DeployMembershipAllowlistRegistrySecure \
 *       --rpc-url $BASE_RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 *
 *   Base Sepolia (testnet):
 *     forge script script/DeployMembershipAllowlistRegistrySecure.s.sol:DeployMembershipAllowlistRegistrySecure \
 *       --rpc-url $BASE_SEPOLIA_RPC_URL \
 *       --broadcast \
 *       --verify \
 *       -vvvv
 */
contract DeployMembershipAllowlistRegistrySecure is Script {
    // Known membership NFT contract addresses
    address constant BASE_MAINNET_MEMBERSHIP_NFT = 0xb83DFE710F0C42A10468ba3F4be300Fd4c5763EB;
    address constant BASE_SEPOLIA_MEMBERSHIP_NFT = 0x2152D2F52C62D2fFa36ba0A5cee4E63fd6A2b643;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Determine which membership NFT to use based on chain
        address membershipNFT;
        string memory networkName;
        
        if (block.chainid == 8453) {
            // Base Mainnet
            membershipNFT = BASE_MAINNET_MEMBERSHIP_NFT;
            networkName = "Base Mainnet";
        } else if (block.chainid == 84532) {
            // Base Sepolia
            membershipNFT = BASE_SEPOLIA_MEMBERSHIP_NFT;
            networkName = "Base Sepolia";
        } else {
            // Allow override via environment variable for other networks
            membershipNFT = vm.envAddress("MEMBERSHIP_NFT_ADDRESS");
            networkName = "Custom Network";
        }

        console.log("==========================================");
        console.log("Deploying MembershipAllowlistRegistrySecure");
        console.log("==========================================");
        console.log("Network:", networkName);
        console.log("Chain ID:", block.chainid);
        console.log("Membership NFT:", membershipNFT);
        console.log("==========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the secure registry
        MembershipAllowlistRegistrySecure registry = new MembershipAllowlistRegistrySecure(membershipNFT);

        vm.stopBroadcast();

        console.log("");
        console.log("==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("MembershipAllowlistRegistrySecure:", address(registry));
        console.log("Membership NFT:", membershipNFT);
        console.log("==========================================");
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify the contract on Basescan");
        console.log("2. Update marketplace to use new registry:");
        console.log("   marketplace.setSellerRegistry(", address(registry), ")");
        console.log("3. Update frontend to handle signature flow");
        console.log("==========================================");
    }
}


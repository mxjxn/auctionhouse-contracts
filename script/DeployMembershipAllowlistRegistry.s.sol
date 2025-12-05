// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/MembershipAllowlistRegistry.sol";
import "../src/DummyERC721.sol";

/**
 * @title DeployMembershipAllowlistRegistry
 * @notice Deployment script for MembershipAllowlistRegistry contract
 * @dev Can be used to deploy the registry on any network
 */
contract DeployMembershipAllowlistRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address membershipNFTAddress = vm.envAddress("MEMBERSHIP_NFT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        console.log("==========================================");
        console.log("Deploying MembershipAllowlistRegistry");
        console.log("==========================================");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("Membership NFT Address:", membershipNFTAddress);
        console.log("==========================================");

        // Deploy MembershipAllowlistRegistry
        console.log("\nDeploying MembershipAllowlistRegistry...");
        MembershipAllowlistRegistry registry = new MembershipAllowlistRegistry(membershipNFTAddress);
        console.log("MembershipAllowlistRegistry deployed at:", address(registry));
        console.log("NFT Contract:", registry.getNftContract());

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("MembershipAllowlistRegistry:", address(registry));
        console.log("Membership NFT Contract:", membershipNFTAddress);
        console.log("==========================================");
    }
}

/**
 * @title DeployMembershipAllowlistRegistryWithMockNFT
 * @notice Deployment script that also deploys a mock NFT for testing
 * @dev Useful for local testing or testnet deployments
 */
contract DeployMembershipAllowlistRegistryWithMockNFT is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        console.log("==========================================");
        console.log("Deploying MembershipAllowlistRegistry with Mock NFT");
        console.log("==========================================");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        // Deploy mock NFT contract
        console.log("\n1. Deploying Mock NFT contract...");
        DummyERC721 mockNFT = new DummyERC721("Membership NFT", "MEMBERSHIP");
        console.log("Mock NFT deployed at:", address(mockNFT));

        // Deploy MembershipAllowlistRegistry
        console.log("\n2. Deploying MembershipAllowlistRegistry...");
        MembershipAllowlistRegistry registry = new MembershipAllowlistRegistry(address(mockNFT));
        console.log("MembershipAllowlistRegistry deployed at:", address(registry));
        console.log("NFT Contract:", registry.getNftContract());

        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("Deployment Complete!");
        console.log("==========================================");
        console.log("MembershipAllowlistRegistry:", address(registry));
        console.log("Mock NFT:", address(mockNFT));
        console.log("\nTo grant membership, call mockNFT.mint(address)");
        console.log("==========================================");
    }
}


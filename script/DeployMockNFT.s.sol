// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/DummyERC721.sol";

/**
 * @title DeployMockNFT
 * @notice Deploy Mock NFT contracts from each of the three test wallets
 * - Index 0: Wallet 1 (Seller)
 * - Index 1: Wallet 2 (Buyer)
 * - Index 2: Wallet 3 (Deployer)
 */
contract DeployMockNFT is Script {
    function run() external {
        // Try to get MNEMONIC - use vm.envOr to avoid revert if not found
        string memory mnemonic = vm.envOr("MNEMONIC", string(""));
        
        // Check if mnemonic is actually set
        if (bytes(mnemonic).length == 0) {
            console.log("ERROR: MNEMONIC environment variable not found!");
            console.log("Please ensure MNEMONIC is exported in your environment.");
            console.log("Try: export MNEMONIC=\"your mnemonic\"");
            console.log("Or: set -a && source .env.local && set +a && forge script ...");
            revert("MNEMONIC environment variable required");
        }
        
        console.log("MNEMONIC found, deriving wallets...");
        
        address wallet1 = vm.addr(vm.deriveKey(mnemonic, 0));
        address wallet2 = vm.addr(vm.deriveKey(mnemonic, 1));
        address wallet3 = vm.addr(vm.deriveKey(mnemonic, 2));
        
        console.log("==========================================");
        console.log("Deploying Mock NFT Contracts");
        console.log("==========================================");
        console.log("Wallet 1 (Index 0):", wallet1);
        console.log("Wallet 2 (Index 1):", wallet2);
        console.log("Wallet 3 (Index 2):", wallet3);
        console.log("Chain ID:", block.chainid);
        console.log("==========================================");

        // Deploy from Wallet 1 (Index 0)
        console.log("\n--- Deploying from Wallet 1 (Index 0) ---");
        uint256 wallet1Key = vm.deriveKey(mnemonic, 0);
        vm.startBroadcast(wallet1Key);
        
        DummyERC721 mockNFT1 = new DummyERC721("Cryptoart Membership 1", "CRYPTOART1");
        console.log("Mock NFT 1 Address:", address(mockNFT1));
        
        vm.stopBroadcast();

        // Deploy from Wallet 2 (Index 1)
        console.log("\n--- Deploying from Wallet 2 (Index 1) ---");
        uint256 wallet2Key = vm.deriveKey(mnemonic, 1);
        vm.startBroadcast(wallet2Key);
        
        DummyERC721 mockNFT2 = new DummyERC721("Cryptoart Membership 2", "CRYPTOART2");
        console.log("Mock NFT 2 Address:", address(mockNFT2));
        
        vm.stopBroadcast();

        // Deploy from Wallet 3 (Index 2)
        console.log("\n--- Deploying from Wallet 3 (Index 2) ---");
        uint256 wallet3Key = vm.deriveKey(mnemonic, 2);
        vm.startBroadcast(wallet3Key);
        
        DummyERC721 mockNFT3 = new DummyERC721("Cryptoart Membership 3", "CRYPTOART3");
        console.log("Mock NFT 3 Address:", address(mockNFT3));
        
        vm.stopBroadcast();

        console.log("\n==========================================");
        console.log("All Deployments Complete!");
        console.log("==========================================");
        console.log("Mock NFT 1 (Wallet 1):", address(mockNFT1));
        console.log("Mock NFT 2 (Wallet 2):", address(mockNFT2));
        console.log("Mock NFT 3 (Wallet 3):", address(mockNFT3));
        console.log("==========================================");
    }
}


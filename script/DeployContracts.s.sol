// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/MarketplaceCore.sol";
import "../src/MarketplaceUpgradeable.sol";

contract DeployContracts is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy MarketplaceUpgradeable contract
        MarketplaceUpgradeable marketplaceUpgradeable = new MarketplaceUpgradeable();
        console.log("MarketplaceUpgradeable deployed at:", address(marketplaceUpgradeable));

        // Initialize the MarketplaceUpgradeable contract
        marketplaceUpgradeable.initialize(msg.sender);

        vm.stopBroadcast();
    }
}
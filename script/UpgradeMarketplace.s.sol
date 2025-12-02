// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "lib/openzeppelin-foundry-upgrades/src/Upgrades.sol";
import { Options } from "lib/openzeppelin-foundry-upgrades/src/Options.sol";
import "../src/MarketplaceUpgradeable.sol";

contract UpgradeMarketplace is Script {
    // Base Sepolia addresses
    address constant MARKETPLACE_PROXY = 0xfd35bF63448595377d5bc2fCB435239Ba2AFB3ea;
    address constant MOCK_ROYALTY_ENGINE = 0xBB428171D8B612D7185A5C25118Ef7EdC3089B37;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Configure options for external library linking
        Options memory options;
        options.unsafeAllow = "external-library-linking";
        
        // Upgrade the proxy using OpenZeppelin Upgrades library
        console.log("Upgrading proxy at:", MARKETPLACE_PROXY);
        Upgrades.upgradeProxy(
            MARKETPLACE_PROXY,
            "MarketplaceUpgradeable.sol:MarketplaceUpgradeable",
            "",
            options
        );
        console.log("Proxy upgraded successfully");
        
        // Set the MockRoyaltyEngine
        MarketplaceUpgradeable marketplace = MarketplaceUpgradeable(payable(MARKETPLACE_PROXY));
        marketplace.setRoyaltyEngineV1(MOCK_ROYALTY_ENGINE);
        console.log("MockRoyaltyEngine set at:", MOCK_ROYALTY_ENGINE);
        
        vm.stopBroadcast();
        
        console.log("Upgrade and configuration complete!");
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IMarketplaceCore} from "../src/IMarketplaceCore.sol";

/**
 * @title WithdrawFees
 * @notice Script to check and withdraw accumulated marketplace fees
 * 
 * Usage:
 *   forge script script/WithdrawFees.s.sol:CheckFees --rpc-url $RPC_URL -vvv
 *   forge script script/WithdrawFees.s.sol:WithdrawFees --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
 */
contract WithdrawFees is Script {
    // Base Mainnet Marketplace Proxy
    address constant MARKETPLACE_PROXY = 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9;
    
    // Fee recipient address
    address constant FEE_RECIPIENT = 0x6dA173B1d50F7Bc5c686f8880C20378965408344;
    
    // ETH address (address(0) for native ETH)
    address constant ETH_ADDRESS = address(0);

    function checkFees() public view {
        IMarketplaceCore marketplace = IMarketplaceCore(MARKETPLACE_PROXY);
        
        console.log("=== Marketplace Fee Information ===");
        console.log("Marketplace Address:", MARKETPLACE_PROXY);
        console.log("Fee Recipient:", FEE_RECIPIENT);
        
        // Check contract ETH balance
        uint256 contractBalance = MARKETPLACE_PROXY.balance;
        console.log("Contract ETH Balance:", contractBalance);
        console.log("Contract ETH Balance (ETH):", contractBalance / 1e18, "ETH");
        
        // Try to check accumulated fees (only works after contract upgrade)
        try marketplace.feesCollected(ETH_ADDRESS) returns (uint256 accumulatedFees) {
            console.log("Accumulated ETH Fees (from mapping):", accumulatedFees);
            console.log("Accumulated ETH Fees (ETH):", accumulatedFees / 1e18, "ETH");
            
            if (contractBalance > accumulatedFees) {
                uint256 difference = contractBalance - accumulatedFees;
                console.log("\nWarning: Contract has more ETH than accumulated fees.");
                console.log("Difference:", difference);
                console.log("Difference (ETH):", difference / 1e18, "ETH");
                console.log("This may indicate other funds in the contract.");
            } else if (contractBalance < accumulatedFees) {
                console.log("\nNote: Accumulated fees exceed contract balance.");
                console.log("This may indicate fees were partially withdrawn or contract has insufficient balance.");
            }
        } catch {
            console.log("\nNote: Cannot query feesCollected mapping directly.");
            console.log("This feature requires a contract upgrade.");
            console.log("For now, the contract balance represents available funds.");
            console.log("If the contract only holds fees, the balance equals accumulated fees.");
        }
        
        console.log("\n=== To Withdraw Fees ===");
        console.log("Run: forge script script/WithdrawFees.s.sol:WithdrawFees --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv");
    }

    function withdrawFees() public {
        IMarketplaceCore marketplace = IMarketplaceCore(MARKETPLACE_PROXY);
        
        // Check contract balance
        uint256 contractBalance = MARKETPLACE_PROXY.balance;
        
        console.log("=== Withdrawing Marketplace Fees ===");
        console.log("Marketplace Address:", MARKETPLACE_PROXY);
        console.log("Fee Recipient:", FEE_RECIPIENT);
        console.log("Contract ETH Balance:", contractBalance);
        console.log("Contract ETH Balance (ETH):", contractBalance / 1e18, "ETH");
        
        // Try to get exact accumulated fees (only works after contract upgrade)
        uint256 amountToWithdraw = contractBalance;
        try marketplace.feesCollected(ETH_ADDRESS) returns (uint256 accumulatedFees) {
            console.log("Accumulated ETH Fees (from mapping):", accumulatedFees);
            console.log("Accumulated ETH Fees (ETH):", accumulatedFees / 1e18, "ETH");
            amountToWithdraw = accumulatedFees;
            
            if (accumulatedFees == 0) {
                console.log("No accumulated fees found. Nothing to withdraw.");
                return;
            }
        } catch {
            console.log("Note: Cannot query feesCollected mapping. Using contract balance.");
            if (contractBalance == 0) {
                console.log("No ETH balance found. Nothing to withdraw.");
                return;
            }
        }
        
        // Withdraw fees
        // Note: This requires admin privileges
        console.log("\nWithdrawing", amountToWithdraw / 1e18, "ETH...");
        marketplace.withdraw(amountToWithdraw, payable(FEE_RECIPIENT));
        
        console.log("Fees withdrawn successfully!");
        
        // Check remaining balance
        uint256 remainingBalance = MARKETPLACE_PROXY.balance;
        console.log("Remaining contract balance:", remainingBalance);
        console.log("Remaining contract balance (ETH):", remainingBalance / 1e18, "ETH");
    }

    function withdrawFeesPartial(uint256 amount) public {
        IMarketplaceCore marketplace = IMarketplaceCore(MARKETPLACE_PROXY);
        
        console.log("=== Withdrawing Partial Marketplace Fees ===");
        console.log("Marketplace Address:", MARKETPLACE_PROXY);
        console.log("Fee Recipient:", FEE_RECIPIENT);
        console.log("Amount to withdraw:", amount);
        console.log("Amount to withdraw (ETH):", amount / 1e18, "ETH");
        
        // Withdraw specified amount
        // Note: This requires admin privileges
        marketplace.withdraw(amount, payable(FEE_RECIPIENT));
        
        console.log("Fees withdrawn successfully!");
    }

    function withdrawERC20Fees(address erc20, uint256 amount) public {
        IMarketplaceCore marketplace = IMarketplaceCore(MARKETPLACE_PROXY);
        
        console.log("=== Withdrawing ERC20 Marketplace Fees ===");
        console.log("Marketplace Address:", MARKETPLACE_PROXY);
        console.log("ERC20 Token:", erc20);
        console.log("Fee Recipient:", FEE_RECIPIENT);
        console.log("Amount to withdraw:", amount);
        
        // Withdraw ERC20 fees
        // Note: This requires admin privileges
        marketplace.withdraw(erc20, amount, payable(FEE_RECIPIENT));
        
        console.log("ERC20 fees withdrawn successfully!");
    }
}


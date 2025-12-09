# Ethereum Mainnet Deployment Guide

This guide explains how to deploy the Auctionhouse contracts to Ethereum Mainnet.

## Prerequisites

1. **Environment Setup**
   - Foundry installed and configured
   - Access to Ethereum mainnet RPC endpoint
   - Sufficient ETH in deployer wallet for gas fees

2. **Required Environment Variables**
   ```bash
   export PRIVATE_KEY="0x..."  # Deployer private key
   export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"  # Or your RPC provider
   ```

3. **Optional Environment Variables**
   ```bash
   export OWNER="0x..."  # Marketplace owner (defaults to deployer)
   export MEMBERSHIP_NFT="0x..."  # Existing membership NFT address (will deploy mock if not set)
   export ROYALTY_ENGINE="0x..."  # Override royalty engine (defaults to Manifold's mainnet address)
   ```

## Deployment Addresses

### Manifold Royalty System (Ethereum Mainnet)

| Contract | Address | Source |
|----------|---------|--------|
| **Royalty Engine V1** | `0x0385603ab55642cb4Dd5De3aE9e306809991804f` | [royaltyregistry.xyz](https://royaltyregistry.xyz) |
| **Royalty Registry** | `0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D` | [royaltyregistry.xyz](https://royaltyregistry.xyz) |

These addresses are automatically used by the deployment script.

## Step 1: Simulate Deployment (Estimate Gas Costs)

Before deploying, simulate the transaction to estimate gas costs:

```bash
cd packages/auctionhouse-contracts

forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  -vvv
```

**Important**: Do NOT include the `--broadcast` flag when simulating. This will:
- Show you the estimated gas costs
- Verify the deployment will succeed
- Display all contract addresses that will be deployed

### Expected Output

The simulation will show:
- Estimated gas usage for each contract deployment
- Total estimated cost in ETH
- All contract addresses that will be deployed
- Configuration details

Example output:
```
==========================================
Deploying Auctionhouse Contracts to Ethereum Mainnet
==========================================
Chain ID: 1
Deployer: 0x...
Owner: 0x...
Royalty Engine: 0x0385603ab55642cb4Dd5De3aE9e306809991804f
...

Estimated gas: ~X,XXX,XXX gas
Estimated cost: ~X.XX ETH (at current gas price)
```

## Step 2: Deploy to Mainnet

Once you've verified the simulation and are ready to deploy:

```bash
forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvv
```

**Flags:**
- `--broadcast`: Actually send the transactions (required for real deployment)
- `--verify`: Verify contracts on Etherscan (requires `ETHERSCAN_API_KEY` env var)
- `-vvv`: Verbose output for debugging

### Verification Setup (Optional)

To verify contracts on Etherscan, set:
```bash
export ETHERSCAN_API_KEY="your_etherscan_api_key"
```

## What Gets Deployed

The deployment script will deploy:

1. **MarketplaceUpgradeable Implementation** - The logic contract
2. **ERC1967Proxy** - The proxy contract (this is the address you'll use)
3. **MembershipSellerRegistry** - Seller registry contract
4. **DummyERC721** (optional) - Mock NFT if `MEMBERSHIP_NFT` not provided

After deployment, the script will:
- Initialize the marketplace with the owner address
- Configure the seller registry
- Set the Manifold Royalty Engine V1 address

## Post-Deployment

### 1. Verify Deployment

Check the deployed contracts:

```bash
# Check marketplace owner
cast call <MARKETPLACE_PROXY> "owner()" --rpc-url $ETH_RPC_URL

# Check seller registry
cast call <MARKETPLACE_PROXY> "sellerRegistry()" --rpc-url $ETH_RPC_URL

# Check royalty engine (via event - no public getter)
# The royalty engine is set via setRoyaltyEngineV1() which emits MarketplaceRoyaltyEngineUpdate event
# Check Etherscan events to verify it was set correctly

# Check if marketplace is enabled
cast call <MARKETPLACE_PROXY> "enabled()" --rpc-url $ETH_RPC_URL
```

### 2. Save Deployment Info

The script automatically saves deployment information to:
```
deployments/deployment-mainnet-<timestamp>.json
```

This file contains:
- All contract addresses
- Chain ID
- Owner address
- Royalty engine address
- Timestamp

### 3. Update Documentation

Update `DEPLOYMENTS.md` with the new deployment information:

```markdown
## Ethereum Mainnet (Chain ID: 1)

**Deployer**: `0x...`  
**Owner**: `0x...`  
**Status**: ✅ Deployed

### Deployed Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| **Marketplace Proxy** | `0x...` | ERC1967 Proxy - **USE THIS** |
| **Marketplace Implementation** | `0x...` | MarketplaceUpgradeable logic |
| **Seller Registry** | `0x...` | MembershipSellerRegistry |
| **Membership NFT** | `0x...` | DummyERC721 or existing NFT |

### Configuration

- **Royalty Engine**: Manifold Royalty Engine V1 (`0x0385603ab55642cb4Dd5De3aE9e306809991804f`)
- **Royalty Registry**: Manifold Royalty Registry (`0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D`)
```

## Gas Cost Estimation

Based on typical deployments, expect:

- **MarketplaceUpgradeable Implementation**: ~2,500,000 gas
- **ERC1967Proxy**: ~500,000 gas
- **MembershipSellerRegistry**: ~1,000,000 gas
- **DummyERC721** (if deployed): ~1,500,000 gas
- **Configuration calls**: ~200,000 gas

**Total**: ~5,700,000 gas (without mock NFT) or ~7,200,000 gas (with mock NFT)

At current gas prices (~20-50 gwei), this translates to approximately:
- **Without mock NFT**: ~0.11 - 0.29 ETH
- **With mock NFT**: ~0.14 - 0.36 ETH

**Note**: Gas prices fluctuate. Always simulate first to get current estimates.

## Troubleshooting

### Error: "This script is for Ethereum Mainnet only"
- Ensure you're connected to Ethereum mainnet (chainId: 1)
- Check your RPC URL is pointing to mainnet

### Error: "Insufficient funds"
- Ensure your deployer wallet has sufficient ETH for gas fees
- Check current gas prices and adjust if needed

### Error: "Contract verification failed"
- Ensure `ETHERSCAN_API_KEY` is set correctly
- Wait a few blocks after deployment before verifying
- Some contracts may need manual verification on Etherscan

## Security Considerations

1. **Private Key Security**
   - Never commit private keys to version control
   - Use environment variables or secure key management
   - Consider using hardware wallets for mainnet deployments

2. **Verification**
   - Always verify contracts on Etherscan
   - Review all deployed contract addresses
   - Test on testnet first

3. **Access Control**
   - Ensure the owner address is correct
   - Consider using a multisig for ownership
   - Review admin functions before deployment

## Next Steps

After successful deployment:

1. Verify all contracts on Etherscan
2. Test marketplace functionality with small transactions
3. Update application configuration with new contract addresses
4. Monitor initial transactions for any issues

## Support

For issues or questions:
- Check existing deployment documentation in `DEPLOYMENTS.md`
- Review contract source code in `src/`
- Check Foundry documentation: https://book.getfoundry.sh/


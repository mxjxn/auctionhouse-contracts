# Quick Deployment Reference - Ethereum Mainnet

## Foundry Command to Simulate Deployment (Estimate Gas)

```bash
forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  -vvv
```

**Note**: Remove `--broadcast` flag to simulate only (estimate gas costs).

## Foundry Command to Deploy

```bash
forge script script/DeployMainnet.s.sol:DeployMainnet \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  -vvv
```

## Required Environment Variables

```bash
export PRIVATE_KEY="0x..."  # Deployer private key
export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"  # Mainnet RPC
```

## Optional Environment Variables

```bash
export OWNER="0x..."  # Marketplace owner (defaults to deployer)
export MEMBERSHIP_NFT="0x..."  # Existing membership NFT (will deploy mock if not set)
export ROYALTY_ENGINE="0x..."  # Override royalty engine (defaults to Manifold's)
export ETHERSCAN_API_KEY="your_key"  # For contract verification
```

## Manifold Royalty Engine (Auto-configured)

- **Royalty Engine V1**: `0x0385603ab55642cb4Dd5De3aE9e306809991804f`
- **Royalty Registry**: `0xaD2184FB5DBcfC05d8f056542fB25b04fa32A95D`

These are automatically used by the deployment script.

## What Gets Deployed

1. **MarketplaceUpgradeable** (implementation)
2. **ERC1967Proxy** (use this address)
3. **MembershipSellerRegistry**
4. **DummyERC721** (if `MEMBERSHIP_NFT` not provided)

The script automatically:
- Initializes marketplace with owner
- Configures seller registry
- Sets Manifold Royalty Engine V1

## Estimated Gas Costs

- **Without mock NFT**: ~5,700,000 gas
- **With mock NFT**: ~7,200,000 gas

At 20-50 gwei: ~0.11-0.36 ETH

**Always simulate first to get current estimates!**

## Full Documentation

See [MAINNET_DEPLOYMENT.md](./MAINNET_DEPLOYMENT.md) for complete deployment guide.


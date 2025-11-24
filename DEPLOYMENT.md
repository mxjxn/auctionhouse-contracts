# Auctionhouse Contracts Deployment Guide

This guide covers deploying the Auctionhouse contracts to local (Anvil) and Base Sepolia testnet.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Deployment (Anvil)](#local-deployment-anvil)
- [Base Sepolia Deployment](#base-sepolia-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

1. **Foundry** - Install from [getfoundry.sh](https://book.getfoundry.sh/getting-started/installation)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Node.js** - For dependency management (if using npm/pnpm)

### Environment Setup

1. Clone the repository and navigate to the auctionhouse contracts package:
   ```bash
   cd packages/auctionhouse-contracts
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Build the contracts:
   ```bash
   forge build
   ```

## Local Deployment (Anvil)

### Step 1: Start Anvil

Start a local Anvil node in a separate terminal:

```bash
anvil
```

This will start Anvil on `http://localhost:8545` with 10 default accounts.

### Step 2: Set Environment Variables

Set the required environment variables:

```bash
# Use one of Anvil's default private keys (first account)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Optional: Set owner address (defaults to deployer)
export OWNER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

### Step 3: Deploy Contracts

Use the deployment script:

```bash
./scripts/deploy.sh local
```

Or deploy manually with forge:

```bash
forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url http://localhost:8545 \
    --broadcast
```

### Step 4: Verify Deployment

The deployment script will:
- Deploy a mock NFT contract (DummyERC721) for the seller registry
- Deploy MarketplaceUpgradeable logic contract
- Deploy MarketplaceUpgradeable proxy (UUPS)
- Deploy MembershipSellerRegistry
- Configure the marketplace with the seller registry
- Save deployment addresses to `deployments/deployment-31337.json` (31337 is Anvil's chain ID)

Check the console output and the deployment JSON file for all contract addresses.

## Base Sepolia Deployment

### Step 1: Get Base Sepolia ETH

You'll need Base Sepolia ETH for gas fees. Get it from:
- [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- Or bridge from Ethereum Sepolia

### Step 2: Set Environment Variables

```bash
# Required: Your deployer private key (without 0x prefix)
export PRIVATE_KEY=your_private_key_here

# Optional: Set owner address (defaults to deployer)
export OWNER=0xYourOwnerAddress

# Optional: Custom RPC URL (defaults to public Base Sepolia RPC)
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
```

**⚠️ Security Warning**: Never commit your private key to version control. Use environment variables or a secure key management system.

### Step 3: Deploy Contracts

Use the deployment script:

```bash
./scripts/deploy.sh base-sepolia
```

Or deploy manually with forge:

```bash
forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify
```

### Step 4: Verify Deployment

The deployment script will save addresses to `deployments/deployment-84532.json` (84532 is Base Sepolia's chain ID).

You can verify the contracts on Base Sepolia explorer:
- [Base Sepolia Explorer](https://sepolia.basescan.org/)

## Post-Deployment Configuration

After deployment, you may want to configure additional settings:

### Set Marketplace Fees

```bash
cast send <MARKETPLACE_PROXY_ADDRESS> \
    "setFees(uint16,uint16)" \
    <MARKETPLACE_FEE_BPS> <REFERRER_FEE_BPS> \
    --rpc-url <RPC_URL> \
    --private-key <PRIVATE_KEY>
```

Example:
```bash
# Set 2.5% marketplace fee and 1% referrer fee
cast send 0x... "setFees(uint16,uint16)" 250 100 \
    --rpc-url http://localhost:8545 \
    --private-key $PRIVATE_KEY
```

### Set Royalty Engine

```bash
cast send <MARKETPLACE_PROXY_ADDRESS> \
    "setRoyaltyEngineV1(address)" \
    <ROYALTY_ENGINE_ADDRESS> \
    --rpc-url <RPC_URL> \
    --private-key <PRIVATE_KEY>
```

### Mint Mock NFT for Testing

To test the seller registry, mint an NFT from the mock contract:

```bash
cast send <MOCK_NFT_ADDRESS> \
    "mint(address)" \
    <RECIPIENT_ADDRESS> \
    --rpc-url <RPC_URL> \
    --private-key <PRIVATE_KEY>
```

## Verification

### Check Contract Addresses

All deployment addresses are saved in JSON format:
- Local: `deployments/deployment-31337.json`
- Base Sepolia: `deployments/deployment-84532.json`

### Verify Contract State

Check the marketplace owner:
```bash
cast call <MARKETPLACE_PROXY_ADDRESS> \
    "owner()" \
    --rpc-url <RPC_URL>
```

Check the seller registry:
```bash
cast call <MARKETPLACE_PROXY_ADDRESS> \
    "sellerRegistry()" \
    --rpc-url <RPC_URL>
```

### Test Seller Authorization

Check if an address is authorized to sell:
```bash
cast call <SELLER_REGISTRY_ADDRESS> \
    "isAuthorized(address,bytes)" \
    <SELLER_ADDRESS> 0x \
    --rpc-url <RPC_URL>
```

## Troubleshooting

### Anvil Not Running

**Error**: `Anvil is not running on http://localhost:8545`

**Solution**: Start Anvil in a separate terminal:
```bash
anvil
```

### Insufficient Funds

**Error**: `insufficient funds for gas`

**Solution**: 
- For local: Anvil provides unlimited funds by default
- For Base Sepolia: Get testnet ETH from a faucet

### Contract Verification Failed

**Error**: Contract verification failed on Base Sepolia

**Solution**: 
- Ensure you have an API key set up for the explorer
- Try verifying manually:
  ```bash
  forge verify-contract <CONTRACT_ADDRESS> \
      src/MarketplaceUpgradeable.sol:MarketplaceUpgradeable \
      --chain-id 84532 \
      --etherscan-api-key <API_KEY>
  ```

### Private Key Format

**Error**: Invalid private key format

**Solution**: 
- Remove `0x` prefix if present
- Ensure the key is 64 hex characters
- Example: `ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

### RPC Connection Issues

**Error**: Connection refused or timeout

**Solution**:
- Check your RPC URL is correct
- For Base Sepolia, try the public RPC: `https://sepolia.base.org`
- Check your network connection
- Some RPC providers require API keys

## Deployment Addresses Reference

After deployment, you'll have these contracts:

1. **Mock NFT** (`DummyERC721`) - Used by MembershipSellerRegistry
2. **Marketplace Logic** (`MarketplaceUpgradeable`) - Implementation contract
3. **Marketplace Proxy** (`MarketplaceUpgradeable`) - Upgradeable proxy (use this address)
4. **Seller Registry** (`MembershipSellerRegistry`) - Checks NFT balance for seller authorization

**Important**: Always use the **Marketplace Proxy** address when interacting with the marketplace, not the logic contract address.

## Next Steps

- Read the [Capabilities Documentation](./CAPABILITIES.md) to understand marketplace features
- Check the [Integration Guide](./INTEGRATION_GUIDE.md) for integrating with Creator Core contracts
- Review [Example Contracts](./src/examples/README.md) for implementation patterns



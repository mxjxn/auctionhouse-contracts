#!/bin/bash

# Test script for Marketplace functionality
# Tests: Creating auctions, placing bids, buy-now purchases

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Network configuration
NETWORK=${1:-"base-sepolia"}
CHAIN_ID=84532
RPC_URL=${BASE_SEPOLIA_RPC_URL:-"https://sepolia.base.org"}

if [ "$NETWORK" = "base-sepolia" ]; then
    CHAIN_ID=84532
    RPC_URL=${BASE_SEPOLIA_RPC_URL:-"https://sepolia.base.org"}
elif [ "$NETWORK" = "base-mainnet" ]; then
    CHAIN_ID=8453
    RPC_URL=${BASE_MAINNET_RPC_URL:-"https://mainnet.base.org"}
    echo "WARNING: Running tests on Base Mainnet!"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "Unknown network: $NETWORK"
    echo "Usage: $0 [base-sepolia|base-mainnet]"
    exit 1
fi

print_header "Marketplace Test Script"
echo "Network: $NETWORK"
echo "Chain ID: $CHAIN_ID"
echo "RPC URL: $RPC_URL"

# Load environment variables
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

if [ -f .env.local ]; then
    set -a
    source .env.local
    set +a
fi

# Check for mnemonic
if [ -z "$MNEMONIC" ]; then
    echo "Error: MNEMONIC environment variable not set"
    echo "Set it in .env or .env.local"
    exit 1
fi

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "Error: forge command not found. Please install Foundry."
    exit 1
fi

# Build contracts
print_header "Building Contracts"
forge build

if [ $? -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"

# Run test script
print_header "Running Marketplace Tests"
echo "This will test:"
echo "  1. Minting NFTs"
echo "  2. Creating fixed price listing"
echo "  3. Purchasing fixed price listing"
echo "  4. Creating auction listing"
echo "  5. Placing bids"
echo "  6. Finalizing auction"

forge script script/TestMarketplace.s.sol:TestMarketplace \
    --rpc-url "$RPC_URL" \
    --broadcast \
    -vvv

if [ $? -eq 0 ]; then
    print_header "Tests Completed!"
    echo "Check the transactions on the explorer:"
    if [ "$NETWORK" = "base-sepolia" ]; then
        echo "https://sepolia.basescan.org/"
    else
        echo "https://basescan.org/"
    fi
else
    echo "Tests failed"
    exit 1
fi


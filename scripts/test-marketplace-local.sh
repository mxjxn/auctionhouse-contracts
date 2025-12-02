#!/bin/bash

# Local test script for Marketplace functionality on Anvil
# Tests: Creating auctions, placing bids, buy-now purchases

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if Anvil is running
print_header "Marketplace Local Test Script"
print_info "Checking if Anvil is running..."

if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
    print_warn "Anvil is not running on http://localhost:8545"
    print_info "Starting Anvil in the background..."
    anvil > /tmp/anvil.log 2>&1 &
    ANVIL_PID=$!
    sleep 2
    
    if ! curl -s http://localhost:8545 > /dev/null 2>&1; then
        echo "Failed to start Anvil"
        exit 1
    fi
    
    print_info "Anvil started (PID: $ANVIL_PID)"
    print_info "To stop Anvil: kill $ANVIL_PID"
else
    print_info "Anvil is already running"
fi

# Set Anvil default private keys
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export PRIVATE_KEY_1=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export PRIVATE_KEY_2=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

print_info "Using Anvil default accounts:"
print_info "  Account 0 (Deployer): 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
print_info "  Account 1 (Seller): 0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
print_info "  Account 2 (Buyer): 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

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
echo "  1. Deploying contracts locally"
echo "  2. Minting NFTs"
echo "  3. Creating fixed price listing"
echo "  4. Purchasing fixed price listing"
echo "  5. Creating auction listing"
echo "  6. Placing bids"
echo "  7. Finalizing auction"

forge script script/TestMarketplaceLocal.s.sol:TestMarketplaceLocal \
    --rpc-url http://localhost:8545 \
    --broadcast \
    -vvv

if [ $? -eq 0 ]; then
    print_header "Tests Completed!"
    print_info "All tests passed successfully!"
else
    echo "Tests failed"
    exit 1
fi


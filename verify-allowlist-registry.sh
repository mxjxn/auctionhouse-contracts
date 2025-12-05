#!/bin/bash

# Verify MembershipAllowlistRegistry on Base Mainnet (BaseScan)
# Requires ETHERSCAN_API_KEY or BASESCAN_API_KEY in environment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    print_info "Loading .env..."
    set -a && source .env && set +a
fi

if [ -f .env.local ]; then
    print_info "Loading .env.local..."
    set -a && source .env.local && set +a
fi

# Check for API key
API_KEY=${ETHERSCAN_API_KEY:-${BASESCAN_API_KEY}}
if [ -z "$API_KEY" ]; then
    print_error "ETHERSCAN_API_KEY or BASESCAN_API_KEY not found!"
    print_info "Get your API key from: https://basescan.org/myapikey"
    print_info "Add to .env: ETHERSCAN_API_KEY=your_api_key_here"
    exit 1
fi

# Contract details
CONTRACT_ADDRESS="0xF190fD214844931a92076aeCB5316f769f4A8483"
MEMBERSHIP_NFT_ADDRESS="0x4b212e795b74a36B4CCf744Fc2272B34eC2e9d90"
CHAIN_ID="8453"  # Base Mainnet
VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=${CHAIN_ID}"

# Compiler settings (must match foundry.toml)
COMPILER_VERSION="0.8.26"
OPTIMIZER_RUNS="200"

print_info "=========================================="
print_info "Verifying MembershipAllowlistRegistry"
print_info "=========================================="
print_info "Contract Address: $CONTRACT_ADDRESS"
print_info "Chain: Base Mainnet (Chain ID: $CHAIN_ID)"
print_info "Compiler Version: $COMPILER_VERSION"
print_info "Optimizer Runs: $OPTIMIZER_RUNS"
print_info "=========================================="

# Encode constructor arguments
print_info "Encoding constructor arguments..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" "$MEMBERSHIP_NFT_ADDRESS")
print_info "Constructor args: $CONSTRUCTOR_ARGS"

# Verify contract
print_info "Submitting verification request..."
forge verify-contract $CONTRACT_ADDRESS \
    src/MembershipAllowlistRegistry.sol:MembershipAllowlistRegistry \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key "$API_KEY" \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --constructor-args $CONSTRUCTOR_ARGS \
    --watch

print_info "=========================================="
print_info "Verification Complete!"
print_info "=========================================="
print_info "View contract on BaseScan:"
print_info "https://basescan.org/address/$CONTRACT_ADDRESS#code"
print_info "=========================================="

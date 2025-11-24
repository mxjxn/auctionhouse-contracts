#!/bin/bash

# Deployment script for Auctionhouse Contracts
# Supports local (Anvil) and Base Sepolia testnet

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if network argument is provided
if [ -z "$1" ]; then
    print_error "Network not specified"
    echo "Usage: $0 <local|base-sepolia>"
    exit 1
fi

NETWORK=$1

# Set RPC URL based on network
case $NETWORK in
    local)
        RPC_URL="http://localhost:8545"
        print_info "Deploying to local Anvil network"
        # Check if Anvil is running
        if ! curl -s $RPC_URL > /dev/null 2>&1; then
            print_error "Anvil is not running on $RPC_URL"
            print_info "Start Anvil with: anvil"
            exit 1
        fi
        ;;
    base-sepolia)
        RPC_URL=${BASE_SEPOLIA_RPC_URL:-"https://sepolia.base.org"}
        print_info "Deploying to Base Sepolia testnet"
        ;;
    *)
        print_error "Unknown network: $NETWORK"
        echo "Supported networks: local, base-sepolia"
        exit 1
        ;;
esac

# Load and export environment variables from .env.local if it exists
if [ -f .env.local ]; then
    print_info "Loading environment variables from .env.local..."
    set -a  # Automatically export all variables
    source .env.local
    set +a  # Turn off automatic export
fi

# Strip quotes from MNEMONIC if present (handles both single and double quotes from .env files)
if [ -n "$MNEMONIC" ]; then
    MNEMONIC=$(echo "$MNEMONIC" | sed "s/^[[:space:]]*['\"]//; s/['\"][[:space:]]*$//; s/^[[:space:]]*//; s/[[:space:]]*$//")
fi

# Derive private key from mnemonic if provided
if [ -n "$MNEMONIC" ]; then
    # Use MNEMONIC_INDEX if set, otherwise default to 0
    MNEMONIC_INDEX=${MNEMONIC_INDEX:-0}
    export MNEMONIC_INDEX  # Export for forge script
    export MNEMONIC  # Export for forge script (after quote stripping)
    
    print_info "Using MNEMONIC to derive private key (index $MNEMONIC_INDEX)..."
    DERIVED_PRIVATE_KEY=$(cast wallet private-key "$MNEMONIC" $MNEMONIC_INDEX 2>/dev/null || echo "")
    
    if [ -n "$DERIVED_PRIVATE_KEY" ]; then
        PRIVATE_KEY="$DERIVED_PRIVATE_KEY"
        DERIVED_ADDRESS=$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo "")
        print_info "✓ Derived private key from mnemonic (index $MNEMONIC_INDEX)"
        print_info "  Address: $DERIVED_ADDRESS"
    else
        print_error "Could not derive private key from mnemonic at index $MNEMONIC_INDEX!"
        exit 1
    fi
elif [ -z "$PRIVATE_KEY" ]; then
    print_error "Either PRIVATE_KEY or MNEMONIC environment variable must be set"
    print_info "Set MNEMONIC with: export MNEMONIC=\"your twelve word seed phrase\""
    print_info "Or set PRIVATE_KEY with: export PRIVATE_KEY=your_private_key"
    exit 1
fi

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    print_error "forge command not found. Please install Foundry."
    print_info "Install from: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Build contracts first
print_info "Building contracts..."
forge build

# Deploy contracts
print_info "Deploying contracts to $NETWORK..."
print_info "RPC URL: $RPC_URL"

forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify

if [ $? -eq 0 ]; then
    print_info "Deployment completed successfully!"
    print_info "Deployment addresses saved to deployments/deployment-*.json"
else
    print_error "Deployment failed"
    exit 1
fi




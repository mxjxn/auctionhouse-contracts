#!/bin/bash

# Deployment script for Auctionhouse Contracts to Monad Mainnet
# Chain ID: 143
# RPC: https://monad-mainnet.gateway.tatum.io/
# Rate limit: 25 requests per second
# Batch call limit: 100

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Network configuration
NETWORK="monad-mainnet"
CHAIN_ID=143
RPC_URL=${MONAD_MAINNET_RPC_URL:-"https://monad-mainnet.gateway.tatum.io/"}
RATE_LIMIT_RPS=25
BATCH_CALL_LIMIT=100

print_header "Monad Mainnet Deployment"
print_info "Network: $NETWORK"
print_info "Chain ID: $CHAIN_ID"
print_info "RPC URL: $RPC_URL"
print_warn "Rate limit: $RATE_LIMIT_RPS requests per second"
print_warn "Batch call limit: $BATCH_CALL_LIMIT"

# Load and export environment variables from .env if it exists
if [ -f .env ]; then
    print_info "Loading environment variables from .env..."
    set -a  # Automatically export all variables
    source .env
    set +a  # Turn off automatic export
fi

# Also check .env.local if it exists
if [ -f .env.local ]; then
    print_info "Loading environment variables from .env.local..."
    set -a
    source .env.local
    set +a
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
    print_info "Set MNEMONIC in .env file with: MNEMONIC=\"your twelve word seed phrase\""
    print_info "Set MNEMONIC_INDEX in .env file with: MNEMONIC_INDEX=0"
    print_info "Or set PRIVATE_KEY with: export PRIVATE_KEY=your_private_key"
    exit 1
fi

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    print_error "forge command not found. Please install Foundry."
    print_info "Install from: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# Check if cast is installed (needed for wallet operations)
if ! command -v cast &> /dev/null; then
    print_error "cast command not found. Please install Foundry."
    print_info "Install from: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# Verify RPC connection
print_info "Verifying RPC connection..."
if ! cast chain-id --rpc-url "$RPC_URL" > /dev/null 2>&1; then
    print_warn "Could not verify RPC connection, but continuing..."
else
    RPC_CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    if [ "$RPC_CHAIN_ID" = "$CHAIN_ID" ]; then
        print_info "✓ RPC connection verified (Chain ID: $RPC_CHAIN_ID)"
    else
        print_warn "RPC returned chain ID $RPC_CHAIN_ID, expected $CHAIN_ID"
    fi
fi

# Check deployer balance
if [ -n "$DERIVED_ADDRESS" ]; then
    DEPLOYER_ADDRESS="$DERIVED_ADDRESS"
elif [ -n "$PRIVATE_KEY" ]; then
    DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo "")
fi

if [ -n "$DEPLOYER_ADDRESS" ]; then
    print_info "Checking deployer balance..."
    BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    print_info "Deployer address: $DEPLOYER_ADDRESS"
    print_info "Balance: $(cast --to-unit $BALANCE ether) MON"
    
    if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
        print_warn "Deployer has zero or unknown balance. Ensure you have MON for gas fees."
    fi
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Build contracts first
print_header "Building Contracts"
print_info "Building contracts..."
forge build

if [ $? -ne 0 ]; then
    print_error "Build failed"
    exit 1
fi

print_info "✓ Build successful"

# Deploy contracts
print_header "Deploying Contracts"
print_info "Deploying to Monad Mainnet..."
print_info "Using --slow flag to respect rate limits (25 rps)"

# For Monad Mainnet, we use --slow to add delays between transactions
# This helps respect the 25 requests per second rate limit
forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url "$RPC_URL" \
    --chain-id $CHAIN_ID \
    --broadcast \
    --slow

if [ $? -eq 0 ]; then
    print_header "Deployment Complete!"
    print_info "Deployment addresses saved to deployments/deployment-${CHAIN_ID}.json"
    print_info ""
    print_info "Next steps:"
    print_info "1. Verify contract addresses in deployments/deployment-${CHAIN_ID}.json"
    print_info "2. Update your application configuration with the new addresses"
    print_info "3. Configure marketplace settings (fees, royalty engine, etc.)"
else
    print_error "Deployment failed"
    exit 1
fi


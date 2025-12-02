#!/bin/bash

# Deployment script for Auctionhouse Contracts to Base Sepolia Testnet
# Chain ID: 84532
# RPC: https://sepolia.base.org
# Explorer: https://sepolia.basescan.org/

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
NETWORK="base-sepolia"
CHAIN_ID=84532
EXPLORER_URL="https://sepolia.basescan.org"

print_header "Base Sepolia Testnet Deployment"
print_info "Network: $NETWORK"
print_info "Chain ID: $CHAIN_ID"
print_info "Explorer: $EXPLORER_URL"

# Load and export environment variables from .env if it exists
if [ -f .env ]; then
    print_info "Loading environment variables from .env..."
    set -a  # Automatically export all variables
    source .env
    set +a  # Turn off automatic export
fi

# Also check .env.local if it exists
# WARNING: .env.local might override RPC_URL - we'll validate and fix after loading
if [ -f .env.local ]; then
    print_info "Loading environment variables from .env.local..."
    set -a
    source .env.local
    set +a
fi

# CRITICAL: Force Base Sepolia RPC - do not allow override to mainnet
# Check if RPC_URL was set to mainnet (from .env.local or elsewhere)
if [ -n "$RPC_URL" ] && [[ "$RPC_URL" =~ (mainnet|8453) ]] && [[ ! "$RPC_URL" =~ (sepolia|84532|testnet) ]]; then
    print_error "CRITICAL: RPC URL appears to be Base Mainnet, not Base Sepolia!"
    print_error "RPC URL found: $RPC_URL"
    print_error "This script deploys to Base Sepolia (Chain ID: 84532) only."
    print_error "If you want to deploy to Base Mainnet, use a different script."
    exit 1
fi

# Set RPC URL - use BASE_SEPOLIA_RPC_URL if set, otherwise default
if [ -n "$BASE_SEPOLIA_RPC_URL" ]; then
    RPC_URL="$BASE_SEPOLIA_RPC_URL"
    # Validate it's actually a Sepolia endpoint
    if [[ "$RPC_URL" =~ (mainnet|8453) ]] && [[ ! "$RPC_URL" =~ (sepolia|84532|testnet) ]]; then
        print_error "CRITICAL: BASE_SEPOLIA_RPC_URL appears to be Base Mainnet!"
        print_error "RPC URL: $RPC_URL"
        exit 1
    fi
else
    RPC_URL="https://sepolia.base.org"
fi

print_info "RPC URL: $RPC_URL"

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
    
    # Try to derive private key using cast
    # Note: cast wallet private-key requires the mnemonic and index
    DERIVED_PRIVATE_KEY=$(cast wallet private-key "$MNEMONIC" $MNEMONIC_INDEX 2>&1)
    CAST_EXIT_CODE=$?
    
    if [ $CAST_EXIT_CODE -eq 0 ] && [ -n "$DERIVED_PRIVATE_KEY" ] && [[ ! "$DERIVED_PRIVATE_KEY" =~ ^Error ]]; then
        PRIVATE_KEY="$DERIVED_PRIVATE_KEY"
        DERIVED_ADDRESS=$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo "")
        print_info "✓ Derived private key from mnemonic (index $MNEMONIC_INDEX)"
        if [ -n "$DERIVED_ADDRESS" ]; then
            print_info "  Address: $DERIVED_ADDRESS"
        fi
    else
        print_warn "Could not derive private key using cast command."
        print_info "The forge script will derive the key directly from the mnemonic."
        print_info "Continuing with deployment (forge script handles mnemonic derivation)..."
        # Don't exit - let forge script handle the mnemonic directly
        # We just won't be able to check balance beforehand
        DERIVED_ADDRESS=""
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

# CRITICAL: Verify RPC connection and chain ID - FAIL if wrong network
print_info "Verifying RPC connection and chain ID..."
RPC_CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "")

if [ -z "$RPC_CHAIN_ID" ]; then
    print_error "CRITICAL: Could not connect to RPC or get chain ID"
    print_error "RPC URL: $RPC_URL"
    exit 1
fi

if [ "$RPC_CHAIN_ID" != "$CHAIN_ID" ]; then
    print_error "CRITICAL: Wrong network detected!"
    print_error "Expected Chain ID: $CHAIN_ID (Base Sepolia)"
    print_error "RPC Chain ID: $RPC_CHAIN_ID"
    if [ "$RPC_CHAIN_ID" = "8453" ]; then
        print_error "You are connected to Base MAINNET, not Base Sepolia!"
        print_error "This script deploys to Base Sepolia testnet only."
        print_error "If you want to deploy to Base Mainnet, use a different deployment method."
    fi
    print_error "RPC URL: $RPC_URL"
    exit 1
fi

print_info "✓ RPC connection verified (Chain ID: $RPC_CHAIN_ID - Base Sepolia)"

# Check deployer balance (only if we have an address)
if [ -n "$DERIVED_ADDRESS" ]; then
    DEPLOYER_ADDRESS="$DERIVED_ADDRESS"
elif [ -n "$PRIVATE_KEY" ]; then
    DEPLOYER_ADDRESS=$(cast wallet address $PRIVATE_KEY 2>/dev/null || echo "")
fi

if [ -n "$DEPLOYER_ADDRESS" ]; then
    print_info "Checking deployer balance..."
    BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
    print_info "Deployer address: $DEPLOYER_ADDRESS"
    print_info "Balance: $(cast --to-unit $BALANCE ether) ETH"
    
    if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
        print_warn "Deployer has zero or unknown balance. Ensure you have Base Sepolia ETH for gas fees."
        print_info "Get testnet ETH from: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet"
        if [ -z "$SKIP_BALANCE_CHECK" ]; then
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Deployment cancelled"
                exit 1
            fi
        else
            print_info "SKIP_BALANCE_CHECK set, continuing..."
        fi
    fi
else
    print_warn "Could not determine deployer address for balance check."
    print_info "The forge script will derive the address from the mnemonic during deployment."
fi

# Create deployments directory if it doesn't exist
mkdir -p deployments

# Clean and build contracts (required for OpenZeppelin upgrades validation)
print_header "Building Contracts"
print_info "Cleaning previous build artifacts..."
forge clean

print_info "Building contracts with full compilation..."
forge build --force

if [ $? -ne 0 ]; then
    print_error "Build failed"
    exit 1
fi

print_info "✓ Build successful"

# Deploy contracts
print_header "Deploying Contracts"
print_info "Deploying to Base Sepolia testnet..."
print_info "Contracts will be verified on Basescan"

# For Base Sepolia, we use --verify to verify contracts on Basescan
# The ETHERSCAN_API_KEY or BASESCAN_API_KEY should be set in .env
# Skip verification if SKIP_VERIFY is set (useful if verification hangs)
VERIFY_FLAG="--verify"
if [ -n "$SKIP_VERIFY" ]; then
    print_warn "SKIP_VERIFY set, skipping contract verification"
    VERIFY_FLAG=""
fi

forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url "$RPC_URL" \
    --broadcast \
    $VERIFY_FLAG

if [ $? -eq 0 ]; then
    print_header "Deployment Complete!"
    print_info "Deployment addresses saved to deployments/deployment-${CHAIN_ID}.json"
    print_info ""
    print_info "Next steps:"
    print_info "1. Verify contract addresses in deployments/deployment-${CHAIN_ID}.json"
    print_info "2. View contracts on explorer: $EXPLORER_URL"
    print_info "3. Update your application configuration with the new addresses"
    print_info "4. Configure marketplace settings (fees, royalty engine, etc.)"
else
    print_error "Deployment failed"
    exit 1
fi


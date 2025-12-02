#!/bin/bash

# Verify contracts on BaseScan (Base Sepolia) using Etherscan v2 API
# Requires ETHERSCAN_API_KEY in .env or .env.local

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
if [ -z "$ETHERSCAN_API_KEY" ]; then
    print_error "ETHERSCAN_API_KEY not found in environment!"
    print_info "Get your API key from: https://etherscan.io/myapikey"
    print_info "Add to .env.local: ETHERSCAN_API_KEY=your_api_key_here"
    exit 1
fi

# Chain ID for Base Sepolia
CHAIN_ID="84532"
VERIFIER_URL="https://api.etherscan.io/v2/api?chainid=${CHAIN_ID}"

print_header "BaseScan Contract Verification (Etherscan v2 API)"
print_info "Chain: Base Sepolia ($CHAIN_ID)"
print_info "Verifier URL: $VERIFIER_URL"
print_info "API Key: ${ETHERSCAN_API_KEY:0:8}..."

# Base Sepolia deployed addresses (Block 34287105)
MARKETPLACE_PROXY="0xfd35bF63448595377d5bc2fCB435239Ba2AFB3ea"
MARKETPLACE_LOGIC="0x7d4a5787E5fB76B852fa1143cFDD2a1090bd9b55"
MARKETPLACE_LOGIC_2="0xF190fD214844931a92076aeCB5316f769f4A8483"  # Second instance used by proxy
SELLER_REGISTRY="0x4C5c5E94393c1359158B3Ba980c1bd5FB502A7bA"
MOCK_NFT="0xcbFbfA0ABF8E300d3fd7B7c9f316054101278D2B"
MARKETPLACE_LIB="0x7CCDa9A722Bc7CfbbAC737043b2B893718519bA8"
SETTLEMENT_LIB="0x4F6f47168DD8f0989279f25E1e8D2350e02aa677"

# Compiler settings (must match deployment)
COMPILER_VERSION="0.8.26"
OPTIMIZER_RUNS="200"

# Delay between API calls (seconds) - Etherscan has rate limits
API_DELAY=30

print_header "Verifying MarketplaceLib"
print_info "Address: $MARKETPLACE_LIB"
forge verify-contract $MARKETPLACE_LIB \
    src/libs/MarketplaceLib.sol:MarketplaceLib \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --watch || print_warn "MarketplaceLib verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying SettlementLib"
print_info "Address: $SETTLEMENT_LIB"
forge verify-contract $SETTLEMENT_LIB \
    src/libs/SettlementLib.sol:SettlementLib \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --watch || print_warn "SettlementLib verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying DummyERC721 (Mock NFT)"
print_info "Address: $MOCK_NFT"
# Constructor args: name="Cryptoart Membership", symbol="CRYPTOART"
MOCK_NFT_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(string,string)" "Cryptoart Membership" "CRYPTOART")
forge verify-contract $MOCK_NFT \
    src/DummyERC721.sol:DummyERC721 \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --constructor-args $MOCK_NFT_CONSTRUCTOR_ARGS \
    --watch || print_warn "DummyERC721 verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying MarketplaceUpgradeable (Logic)"
print_info "Address: $MARKETPLACE_LOGIC"
# Libraries need to be linked
forge verify-contract $MARKETPLACE_LOGIC \
    src/MarketplaceUpgradeable.sol:MarketplaceUpgradeable \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --libraries src/libs/MarketplaceLib.sol:MarketplaceLib:$MARKETPLACE_LIB \
    --libraries src/libs/SettlementLib.sol:SettlementLib:$SETTLEMENT_LIB \
    --watch || print_warn "MarketplaceUpgradeable verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying MarketplaceUpgradeable (Logic 2 - used by proxy)"
print_info "Address: $MARKETPLACE_LOGIC_2"
forge verify-contract $MARKETPLACE_LOGIC_2 \
    src/MarketplaceUpgradeable.sol:MarketplaceUpgradeable \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --libraries src/libs/MarketplaceLib.sol:MarketplaceLib:$MARKETPLACE_LIB \
    --libraries src/libs/SettlementLib.sol:SettlementLib:$SETTLEMENT_LIB \
    --watch || print_warn "MarketplaceUpgradeable (2) verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying MembershipSellerRegistry"
print_info "Address: $SELLER_REGISTRY"
# Constructor args: membershipNFT address
SELLER_REGISTRY_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address)" $MOCK_NFT)
forge verify-contract $SELLER_REGISTRY \
    src/MembershipSellerRegistry.sol:MembershipSellerRegistry \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --constructor-args $SELLER_REGISTRY_CONSTRUCTOR_ARGS \
    --watch || print_warn "MembershipSellerRegistry verification may have failed or already verified"

print_info "Waiting ${API_DELAY}s before next verification..."
sleep $API_DELAY

print_header "Verifying ERC1967Proxy (Marketplace Proxy)"
print_info "Address: $MARKETPLACE_PROXY"
# Constructor args: implementation address + initialize(owner) calldata
INIT_CALLDATA=$(cast calldata "initialize(address)" "0x6dA173B1d50F7Bc5c686f8880C20378965408344")
PROXY_CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,bytes)" "$MARKETPLACE_LOGIC_2" "$INIT_CALLDATA")
forge verify-contract $MARKETPLACE_PROXY \
    lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy \
    --verifier etherscan \
    --verifier-url "$VERIFIER_URL" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --num-of-optimizations $OPTIMIZER_RUNS \
    --compiler-version $COMPILER_VERSION \
    --constructor-args $PROXY_CONSTRUCTOR_ARGS \
    --watch || print_warn "ERC1967Proxy verification may have failed or already verified"

print_header "Verification Complete!"
print_info ""
print_info "Check verification status on BaseScan:"
print_info "- MarketplaceLib: https://sepolia.basescan.org/address/$MARKETPLACE_LIB#code"
print_info "- SettlementLib: https://sepolia.basescan.org/address/$SETTLEMENT_LIB#code"
print_info "- Mock NFT: https://sepolia.basescan.org/address/$MOCK_NFT#code"
print_info "- Marketplace Logic: https://sepolia.basescan.org/address/$MARKETPLACE_LOGIC#code"
print_info "- Marketplace Logic 2: https://sepolia.basescan.org/address/$MARKETPLACE_LOGIC_2#code"
print_info "- Seller Registry: https://sepolia.basescan.org/address/$SELLER_REGISTRY#code"
print_info "- Marketplace Proxy: https://sepolia.basescan.org/address/$MARKETPLACE_PROXY#code"

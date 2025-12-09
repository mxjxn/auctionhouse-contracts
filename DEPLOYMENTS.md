# Auctionhouse Contracts Deployment Records

This document contains deployment information for the Auctionhouse contracts across different networks.

## Base Mainnet (Chain ID: 8453)

**Deployer**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Owner**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Status**: ✅ Deployed

### Deployed Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| **Marketplace Proxy** | `0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9` | ERC1967 Proxy - **USE THIS** |
| **Marketplace Implementation** | `0x2fc08CE6Dd271C9CE6763182DbAed384fEa1986d` | MarketplaceUpgradeable logic |
| **Royalty Engine** | `0xEF770dFb6D5620977213f55f99bfd781D04BBE15` | Manifold Royalty Engine V1 |
| **Royalty Registry** | `0x3D1151dc590ebF5C04501a7d4E1f8921546774eA` | Manifold Royalty Registry |
| **MembershipSellerRegistry** | `0x372990fd91cf61967325dd5270f50c4192bfb892` | Simple membership check (balanceOf > 0) |
| **OpenSellerRegistry** | `0xBB428171D8B612D7185A5C25118Ef7EdC3089B37` | Open registry with owner-managed blocklist |

### Contract Links

- [Marketplace Proxy on BaseScan](https://basescan.org/address/0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9)
- [Marketplace Implementation on BaseScan](https://basescan.org/address/0x2fc08CE6Dd271C9CE6763182DbAed384fEa1986d)
- [Royalty Engine on BaseScan](https://basescan.org/address/0xEF770dFb6D5620977213f55f99bfd781D04BBE15)
- [Royalty Registry on BaseScan](https://basescan.org/address/0x3D1151dc590ebF5C04501a7d4E1f8921546774eA)
- [MembershipSellerRegistry on BaseScan](https://basescan.org/address/0x372990fd91cf61967325dd5270f50c4192bfb892)
- [OpenSellerRegistry on BaseScan](https://basescan.org/address/0xBB428171D8B612D7185A5C25118Ef7EdC3089B37)

### Deployment Notes

- **Proxy Pattern**: ERC1967 Proxy
- **Royalty Engine**: Uses Manifold Royalty Engine V1 (deployed on mainnet)
- **Membership NFT Contract**: `0x4b212e795b74a36B4CCf744Fc2272B34eC2e9d90` (STP v2)
- **Configuration**: TODO - Verify seller registry and royalty engine are configured

### OpenSellerRegistry Deployment

**Deployment Date**: 2025-12-07  
**Block**: 39145058  
**Transaction Hash**: [`0x204d4a071b6988d292683955e7f51d9a2efa0249003c30878dca11861a895639`](https://basescan.org/tx/0x204d4a071b6988d292683955e7f51d9a2efa0249003c30878dca11861a895639)  
**Deployer/Owner**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Status**: ✅ Successfully Deployed

**Contract Address**: `0xBB428171D8B612D7185A5C25118Ef7EdC3089B37`

**Features**:
- **Allow-all by default**: Everyone can sell unless explicitly blocklisted
- **Owner-managed blocklist**: Only owner can add/remove addresses from blocklist
- Implements `IMarketplaceSellerRegistry` interface
- Gas efficient: Single mapping lookup for authorization

**Blocklist Management**:
```bash
# Block an address
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
  0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 "addToBlocklist(address)" <ADDRESS>

# Block multiple addresses
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
  0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 "addToBlocklistBatch(address[])" "[0xADDR1,0xADDR2]"

# Unblock an address
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
  0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 "removeFromBlocklist(address)" <ADDRESS>

# Check if address is blocklisted
cast call --rpc-url $RPC_URL \
  0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 "isBlocklisted(address)(bool)" <ADDRESS>
```

**Set as Active Registry**:
```bash
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY \
  0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 "setSellerRegistry(address)" 0xBB428171D8B612D7185A5C25118Ef7EdC3089B37
```

---

## Base Sepolia Testnet (Chain ID: 84532) - CURRENT DEPLOYMENT

**Deployment Date**: 2024-11-28  
**Block**: 34297185  
**Deployer**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Owner**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Status**: ✅ Successfully Deployed & Tested

### Deployed Contracts

| Contract | Address | Description |
|----------|---------|-------------|
| **Marketplace Proxy** | `0x5336a0C2476EAdcE32C7f3C58bE809c700e4db2e` | Main entry point (ERC1967 Proxy) - **USE THIS** |
| **Marketplace Implementation** | `0x7DAA7bBedaFEE708cf83Ba740A1c7d7d239243f4` | Logic contract |
| **Seller Registry** | `0x617753FD6Fa31E07b4A7996010D0964f001288d0` | MembershipSellerRegistry |
| **Mock NFT** | `0x843aE43b40c8370dFFc29fF87bE38953f8BbaAec` | DummyERC721 for testing |
| **Mock Royalty Engine** | `0x80e61595597F6C085a35693050b72757DD8cd85d` | Returns empty royalties for testing |
| **MarketplaceLib** | `0x7CCDa9A722Bc7CfbbAC737043b2B893718519bA8` | Library contract (reused) |
| **SettlementLib** | `0x4F6f47168DD8f0989279f25E1e8D2350e02aa677` | Library contract (reused) |

### Contract Links

- [Marketplace Proxy on BaseScan](https://sepolia.basescan.org/address/0x5336a0C2476EAdcE32C7f3C58bE809c700e4db2e)
- [Marketplace Implementation on BaseScan](https://sepolia.basescan.org/address/0x7DAA7bBedaFEE708cf83Ba740A1c7d7d239243f4)
- [Seller Registry on BaseScan](https://sepolia.basescan.org/address/0x617753FD6Fa31E07b4A7996010D0964f001288d0)
- [Mock NFT on BaseScan](https://sepolia.basescan.org/address/0x843aE43b40c8370dFFc29fF87bE38953f8BbaAec)
- [Mock Royalty Engine on BaseScan](https://sepolia.basescan.org/address/0x80e61595597F6C085a35693050b72757DD8cd85d)

### Test Results ✅

All marketplace functionality has been tested successfully on this deployment:

| Test | Status | Details |
|------|--------|---------|
| **Fixed Price Listing** | ✅ Passed | Created listing ID: 1, Price: 0.01 ETH |
| **Auction Listing** | ✅ Passed | Created listing ID: 2, Reserve: 0.005 ETH |
| **Purchase Fixed Price** | ✅ Passed | NFT transferred to buyer |
| **Place Bid** | ✅ Passed | Bid placed at 0.005 ETH |
| **Outbid** | ✅ Passed | Higher bid placed at 0.00525 ETH |
| **Finalize Auction** | ✅ Passed | NFT transferred to winning bidder |

### Deployment Notes

- **Proxy Pattern**: ERC1967 Proxy
- **MockRoyaltyEngine**: Returns empty royalties (Manifold Registry not on Base Sepolia)
- **Libraries**: Reused existing MarketplaceLib and SettlementLib deployments
- **Configuration**: Seller registry and royalty engine configured during deployment

### Deployment Script

```bash
forge script script/DeploySepoliaFresh.s.sol:DeploySepoliaFresh \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --libraries src/libs/MarketplaceLib.sol:MarketplaceLib:0x7ccda9a722bc7cfbbac737043b2b893718519ba8 \
  --libraries src/libs/SettlementLib.sol:SettlementLib:0x4f6f47168dd8f0989279f25e1e8d2350e02aa677 \
  --broadcast -vvv
```

---

## Testing a Deployment

The marketplace can be fully tested using the `TestMarketplace.s.sol` script. Tests are split into phases to account for testnet timing requirements.

### Prerequisites

1. Set environment variables:
```bash
export RPC_URL="https://sepolia.base.org"
export PRIVATE_KEY="0x..."  # Deployer wallet with test ETH
```

2. Update contract addresses in `script/TestMarketplace.s.sol`:
```solidity
address constant MARKETPLACE_PROXY = 0x5336a0C2476EAdcE32C7f3C58bE809c700e4db2e;
address constant MOCK_NFT = 0x843aE43b40c8370dFFc29fF87bE38953f8BbaAec;
address constant SELLER_REGISTRY = 0x617753FD6Fa31E07b4A7996010D0964f001288d0;
```

### Phase 1: Create Listings

Creates fixed-price and auction listings:

```bash
forge script script/TestMarketplace.s.sol:CreateListings \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
```

**Expected Output:**
- Mints 2 NFTs to seller wallet
- Creates fixed-price listing (ID: 1) at 0.01 ETH
- Creates auction listing (ID: 2) with 0.005 ETH reserve

### Phase 2: Purchase and Bid

**Wait 2+ minutes** after Phase 1, then run:

```bash
LISTING_ID=1 AUCTION_ID=2 forge script script/TestMarketplace.s.sol:PurchaseAndBid \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
```

**Expected Output:**
- Purchases fixed-price listing
- Places bid on auction
- Places higher outbid

### Phase 3: Finalize Auction

**Wait until auction ends** (~8 minutes after creation), then run:

```bash
AUCTION_ID=2 forge script script/TestMarketplace.s.sol:FinalizeAuction \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast -vvv
```

**Expected Output:**
- Auction finalized
- NFT transferred to winning bidder
- "All Tests Passed!" message

### Check Listing Status

To check a listing's current state:

```bash
LISTING_ID=1 forge script script/TestMarketplace.s.sol:CheckListingStatus \
  --rpc-url $RPC_URL -vvv
```

---

## Previous Base Sepolia Deployment (Deprecated)

The following deployment had royalty engine configuration issues:

| Contract | Address |
|----------|---------|
| Marketplace Proxy | `0xfd35bF63448595377d5bc2fCB435239Ba2AFB3ea` |
| MarketplaceLib | `0x7CCDa9A722Bc7CfbbAC737043b2B893718519bA8` |
| SettlementLib | `0x4F6f47168DD8f0989279f25E1e8D2350e02aa677` |

**Note**: Use the current deployment above for all testing.

---

## Previous Base Mainnet Deployment

**Note**: There was a previous deployment to Base Mainnet with a different marketplace proxy address:

- **Previous Marketplace Proxy**: `0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9`
- [Previous Proxy on BaseScan](https://basescan.org/address/0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9)

The current deployment (listed above) is the latest and should be used for new integrations.

---

## Integration

### Using the Marketplace

Always use the **Marketplace Proxy** address (`0xBB428171D8B612D7185A5C25118Ef7EdC3089B37`) when interacting with the marketplace, not the logic contract address.

### Environment Variables

For applications using these contracts, set:

```bash
# Base Mainnet
NEXT_PUBLIC_MARKETPLACE_ADDRESS_8453=0xBB428171D8B612D7185A5C25118Ef7EdC3089B37
NEXT_PUBLIC_SELLER_REGISTRY_ADDRESS_8453=0xC485d935009274bC6Fd11d82Dd1C0f4F6fd3eBA9

# Base Sepolia Testnet
NEXT_PUBLIC_MARKETPLACE_ADDRESS_84532=0x589848767eF940Ff7BC5b640232Ef0cA2C7B63B0
NEXT_PUBLIC_SELLER_REGISTRY_ADDRESS_84532=0x6618d91F70B88c452dBCEcB0Aa572E214E3096e9
```

### Contract ABIs

Contract ABIs can be found in:
- `out/MarketplaceUpgradeable.sol/MarketplaceUpgradeable.json`
- `out/MembershipSellerRegistry.sol/MembershipSellerRegistry.json`
- `out/DummyERC721.sol/DummyERC721.json`

---

## Verification

### Base Mainnet

```bash
# Check owner
cast call 0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 \
    "owner()" \
    --rpc-url https://mainnet.base.org

# Check seller registry
cast call 0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 \
    "sellerRegistry()" \
    --rpc-url https://mainnet.base.org

# Check if marketplace is enabled
cast call 0xBB428171D8B612D7185A5C25118Ef7EdC3089B37 \
    "enabled()" \
    --rpc-url https://mainnet.base.org
```

### Base Sepolia

```bash
# Check owner
cast call 0x589848767eF940Ff7BC5b640232Ef0cA2C7B63B0 \
    "owner()" \
    --rpc-url https://sepolia.base.org

# Check seller registry
cast call 0x589848767eF940Ff7BC5b640232Ef0cA2C7B63B0 \
    "sellerRegistry()" \
    --rpc-url https://sepolia.base.org

# Check if marketplace is enabled
cast call 0x589848767eF940Ff7BC5b640232Ef0cA2C7B63B0 \
    "enabled()" \
    --rpc-url https://sepolia.base.org
```

---

## Upgrades

The marketplace uses UUPS proxy pattern, allowing for upgrades. To upgrade:

1. Deploy new implementation contract
2. Call `upgradeTo(address)` on the proxy (requires owner/admin)
3. Verify new implementation is active

**Important**: Always test upgrades on testnet first!


# Auctionhouse Integration Guide

This guide explains how to integrate Manifold Creator Core contracts with the auctionhouse marketplace, covering lazy minting, dynamic pricing, and standard NFT sales.

## Table of Contents

- [Overview](#overview)
- [Integration Patterns](#integration-patterns)
- [Lazy Minting Setup](#lazy-minting-setup)
- [Dynamic Pricing Setup](#dynamic-pricing-setup)
- [Complete Examples](#complete-examples)
- [Best Practices](#best-practices)

## Overview

The auctionhouse marketplace supports three main integration patterns:

1. **Standard NFT Sales**: Mint tokens upfront, transfer to marketplace
2. **Lazy Minting**: Mint tokens on-demand when purchased via marketplace
3. **Dynamic Pricing**: Price changes based on sales progress or time

### Key Interfaces

- **ILazyDelivery**: Required for lazy minting (minting tokens at purchase time)
- **IPriceEngine**: Required for dynamic pricing (price changes based on sales/time)

## Integration Patterns

### Pattern 1: Standard NFT Sales

**Best for**: Edition contracts, fixed-price sales, auctions

**Flow**:
```
1. Mint tokens using Creator Core contract
2. Transfer tokens to marketplace contract
3. Create listing with transfered tokens
4. Marketplace handles sales
```

**Example**:
```solidity
// 1. Mint 100 edition tokens
IERC721CreatorCore creatorCore = IERC721CreatorCore(creatorContract);
uint256[] memory tokenIds = creatorCore.mintBaseBatch(artist, 100);

// 2. Transfer first token to marketplace
IERC721(creatorContract).transferFrom(artist, marketplace, tokenIds[0]);

// 3. Create FIXED_PRICE listing
ListingDetails memory details = ListingDetails({
    initialAmount: 0.05 ether,
    type_: ListingType.FIXED_PRICE,
    totalAvailable: 100,
    totalPerSale: 1,
    // ... other fields
});
```

### Pattern 2: Lazy Minting

**Best for**: On-demand minting, dynamic pricing, reducing upfront gas costs

**Flow**:
```
1. Deploy ILazyDelivery adapter
2. Register adapter as extension on Creator Core
3. Authorize marketplace on adapter
4. Create listing with lazy=true
5. Marketplace calls adapter.deliver() when purchased
```

**Components**:
- `ERC721CreatorLazyDelivery`: Adapter for ERC721 Creator Core contracts
- `ERC1155CreatorLazyDelivery`: Adapter for ERC1155 Creator Core contracts

### Pattern 3: Dynamic Pricing

**Best for**: Bonding curves, Dutch auctions, tiered pricing

**Flow**:
```
1. Deploy IPriceEngine contract
2. Create listing with DYNAMIC_PRICE type
3. Set token address to price engine contract
4. Price engine calculates price based on sales/time
```

**Components**:
- `LinearBondingCurvePriceEngine`: Linear price increase
- `ExponentialBondingCurvePriceEngine`: Exponential price increase
- `DutchAuctionPriceEngine`: Time-based decreasing price
- `StepPricingEngine`: Tiered pricing at quantity thresholds

## Lazy Minting Setup

### Step 1: Deploy the Adapter

```solidity
// Deploy ERC721 adapter
ERC721CreatorLazyDelivery adapter = new ERC721CreatorLazyDelivery(creatorContractAddress);
```

### Step 2: Register Adapter as Extension

On your Creator Core contract, register the adapter as an extension:

```solidity
ICreatorCore(creatorContract).registerExtension(address(adapter), "");
```

### Step 3: Authorize Marketplace

Authorize the marketplace contract to call the adapter:

```solidity
adapter.setAuthorizedMarketplace(marketplaceAddress, true);
```

**Note**: The `setAuthorizedMarketplace` function currently allows any caller. In production, you should add proper access control (e.g., only creator contract owner can authorize).

### Step 4: Create Lazy Listing

When creating a listing, set `lazy: true` and use the adapter address as the token address:

```solidity
TokenDetails memory token = TokenDetails({
    id: 1, // Asset ID (used for tracking)
    address_: address(adapter), // Adapter contract address
    spec: TokenLib.Spec.ERC721,
    lazy: true // Enable lazy minting
});
```

### How It Works

1. Buyer calls `marketplace.purchase(listingId)`
2. Marketplace calls `adapter.deliver(...)`
3. Adapter calls `creatorCore.mintExtension(to, tokenData)`
4. Token is minted directly to buyer
5. Payment is settled

## Dynamic Pricing Setup

### Linear Bonding Curve

Price increases linearly: `price = basePrice + (alreadyMinted * increment)`

```solidity
// Deploy: base price 0.01 ETH, increment 0.001 ETH per token
LinearBondingCurvePriceEngine priceEngine = new LinearBondingCurvePriceEngine(
    0.01 ether,  // basePrice
    0.001 ether  // increment
);

// Create DYNAMIC_PRICE listing
ListingDetails memory details = ListingDetails({
    initialAmount: 0, // Must be 0 for dynamic price
    type_: ListingType.DYNAMIC_PRICE,
    totalAvailable: 1000,
    totalPerSale: 1,
    // ... other fields
});

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: address(priceEngine), // Price engine address
    spec: TokenLib.Spec.ERC721,
    lazy: true // Required for dynamic price
});
```

### Exponential Bonding Curve

Price increases exponentially: `price = basePrice * (multiplier ^ alreadyMinted)`

```solidity
// Deploy: base price 0.01 ETH, 5% increase per token (1.05e18)
ExponentialBondingCurvePriceEngine priceEngine = new ExponentialBondingCurvePriceEngine(
    0.01 ether,  // basePrice
    1.05e18      // multiplier (5% = 1.05 with 18 decimals)
);
```

### Dutch Auction

Price decreases over time from start price to reserve price:

```solidity
// Deploy: starts at 1 ETH, decreases to 0.1 ETH over 7 days
DutchAuctionPriceEngine priceEngine = new DutchAuctionPriceEngine(
    1 ether,              // startPrice
    0.1 ether,            // reservePrice
    block.timestamp,      // startTime
    7 days                // duration
);
```

### Step Pricing

Tiered pricing at quantity thresholds:

```solidity
// Define pricing steps
StepPricingEngine.PricingStep[] memory steps = new StepPricingEngine.PricingStep[](3);
steps[0] = StepPricingEngine.PricingStep({quantity: 10, price: 0.1 ether});  // First 10: 0.1 ETH
steps[1] = StepPricingEngine.PricingStep({quantity: 50, price: 0.2 ether});  // Next 40: 0.2 ETH
steps[2] = StepPricingEngine.PricingStep({quantity: 100, price: 0.3 ether}); // Rest: 0.3 ETH

StepPricingEngine priceEngine = new StepPricingEngine(steps);
```

**Important**: For DYNAMIC_PRICE listings, the token contract must implement both `ILazyDelivery` and `IPriceEngine`. You can deploy the price engine separately and use it as the token address, but you'll also need a lazy delivery adapter.

## Complete Examples

### Example 1: Lazy Minting with Fixed Price

```solidity
// 1. Deploy adapter
ERC721CreatorLazyDelivery adapter = new ERC721CreatorLazyDelivery(creatorContract);

// 2. Register adapter
ICreatorCore(creatorContract).registerExtension(address(adapter), "");

// 3. Authorize marketplace
adapter.setAuthorizedMarketplace(marketplaceAddress, true);

// 4. Create listing
ListingDetails memory details = ListingDetails({
    initialAmount: 0.1 ether,
    type_: ListingType.FIXED_PRICE,
    totalAvailable: 100,
    totalPerSale: 1,
    extensionInterval: 0,
    minIncrementBPS: 0,
    erc20: address(0),
    identityVerifier: address(0),
    startTime: block.timestamp,
    endTime: block.timestamp + 30 days
});

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: address(adapter),
    spec: TokenLib.Spec.ERC721,
    lazy: true
});

uint40 listingId = marketplace.createListing(
    details,
    token,
    DeliveryFees({deliverBPS: 0, deliverFixed: 0}),
    new ListingReceiver[](0),
    false,
    false,
    ""
);
```

### Example 2: Dynamic Pricing with Lazy Minting

```solidity
// 1. Deploy price engine
LinearBondingCurvePriceEngine priceEngine = new LinearBondingCurvePriceEngine(
    0.01 ether,
    0.001 ether
);

// 2. Deploy adapter (must also implement IPriceEngine or use separate contracts)
// For this example, we'll use a combined approach
// In practice, you may need a wrapper contract that implements both interfaces

// 3. Create DYNAMIC_PRICE listing
ListingDetails memory details = ListingDetails({
    initialAmount: 0, // Must be 0
    type_: ListingType.DYNAMIC_PRICE,
    totalAvailable: 1000,
    totalPerSale: 1,
    extensionInterval: 0,
    minIncrementBPS: 0,
    erc20: address(0),
    identityVerifier: address(0),
    startTime: block.timestamp,
    endTime: block.timestamp + 30 days
});

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: address(priceEngine), // Price engine address
    spec: TokenLib.Spec.ERC721,
    lazy: true
});

uint40 listingId = marketplace.createListing(
    details,
    token,
    DeliveryFees({deliverBPS: 0, deliverFixed: 0}),
    new ListingReceiver[](0),
    false,
    false,
    ""
);
```

**Note**: For DYNAMIC_PRICE listings, the contract at `token.address_` must implement both `ILazyDelivery` and `IPriceEngine`. You may need to create a wrapper contract that combines both, or modify the adapter to also implement `IPriceEngine`.

## Best Practices

### Security

1. **Access Control**: Implement proper access control for `setAuthorizedMarketplace()`. Only the creator contract owner should be able to authorize marketplaces.

2. **EOA Check**: The adapters include an EOA check to prevent contract addresses from receiving lazy-minted tokens. This prevents exploit patterns where contracts revert if they don't receive desired attributes.

3. **Token Data**: Use the `assetId` and `listingId` parameters to encode meaningful data in the token minting process, but be careful not to expose sensitive information.

### Gas Optimization

1. **Batch Minting**: For standard sales, use `mintBaseBatch()` to mint multiple tokens at once.

2. **Lazy Minting**: Lazy minting reduces upfront gas costs for sellers since tokens aren't minted until purchased.

3. **Price Engine**: Keep price calculation logic simple and gas-efficient. Complex calculations in `price()` can become expensive.

### Integration Tips

1. **Testing**: Always test adapters with your specific Creator Core contract before deploying to mainnet.

2. **Extension Registration**: Ensure the adapter is properly registered as an extension before creating listings.

3. **Marketplace Authorization**: Double-check that the marketplace address is authorized before creating listings.

4. **Asset IDs**: Use meaningful asset IDs to track different collections or series within the same Creator Core contract.

5. **Price Engine Selection**: Choose the appropriate price engine based on your use case:
   - Linear: Simple, predictable price increases
   - Exponential: Faster price growth, good for limited editions
   - Dutch Auction: Time-based urgency, good for launch sales
   - Step Pricing: Clear tiers, good for milestone-based pricing

## Troubleshooting

### "Unauthorized marketplace" Error

- Ensure `setAuthorizedMarketplace()` was called with `true`
- Verify the marketplace address is correct
- Check that the adapter contract is correctly deployed

### "Invalid creator contract" Error

- Verify the Creator Core contract implements `IERC721CreatorCore` or `IERC1155CreatorCore`
- Check that the contract address is correct

### "Cannot deliver to contract" Error

- This is intentional - lazy minting only works with EOA addresses
- If you need to deliver to contracts, modify the `onlyEOA` modifier (not recommended for security)

### Price Engine Not Working

- For DYNAMIC_PRICE listings, ensure `initialAmount` is 0
- Verify the price engine contract implements `IPriceEngine`
- Check that the price engine address is correctly set in `TokenDetails`

## Additional Resources

- [Auctionhouse Capabilities Documentation](./CAPABILITIES.md)
- [Creator Core Contracts Documentation](../../creator-core-contracts/README.md)
- [Manifold Creator Core Architecture](https://docs.manifold.xyz/v/manifold-for-developers/manifold-creator-architecture/overview)


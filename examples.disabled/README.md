# Auctionhouse Integration Examples

This directory contains example contracts and adapters for integrating Manifold Creator Core contracts with the auctionhouse marketplace.

## Contracts

### Lazy Delivery Adapters

These adapters enable lazy minting (on-demand minting at purchase time) for Creator Core contracts:

- **ERC721CreatorLazyDelivery**: Adapter for ERC721 Creator Core contracts
- **ERC1155CreatorLazyDelivery**: Adapter for ERC1155 Creator Core contracts  
- **ERC721CreatorLazyDeliveryWithPricing**: Combined adapter that implements both `ILazyDelivery` and `IPriceEngine` for dynamic pricing

### Price Engines

These contracts implement the `IPriceEngine` interface for dynamic pricing:

- **LinearBondingCurvePriceEngine**: Linear price increase per token (`price = basePrice + (alreadyMinted * increment)`)
- **ExponentialBondingCurvePriceEngine**: Exponential price increase (`price = basePrice * (multiplier ^ alreadyMinted)`)
- **DutchAuctionPriceEngine**: Time-based decreasing price (price decreases from start to reserve over duration)
- **StepPricingEngine**: Tiered pricing at quantity thresholds

### On-Chain Art Generators

These contracts generate SVG art on-chain, similar to the DynamicSVGExample:

- **GenerativePolygonArt**: Unique geometric polygon patterns with animated gradients
- **WaveInterferenceArt**: Wave interference patterns using SVG filters (GLSL-inspired)
- **FractalArt**: Fractal-like patterns using SVG turbulence filters
- **PlasmaArt**: Plasma effects using SVG filters that simulate GLSL shader techniques

See [ART_EXAMPLES.md](./ART_EXAMPLES.md) for detailed information about the art generators.

## Usage

See [INTEGRATION_GUIDE.md](../INTEGRATION_GUIDE.md) for detailed usage instructions and examples.

## Quick Start

### Lazy Minting

```solidity
// 1. Deploy adapter
ERC721CreatorLazyDelivery adapter = new ERC721CreatorLazyDelivery(creatorContract);

// 2. Register as extension
ICreatorCore(creatorContract).registerExtension(address(adapter), "");

// 3. Authorize marketplace
adapter.setAuthorizedMarketplace(marketplaceAddress, true);

// 4. Create listing with lazy=true
```

### Dynamic Pricing

```solidity
// Option 1: Use combined adapter
ERC721CreatorLazyDeliveryWithPricing adapter = new ERC721CreatorLazyDeliveryWithPricing(
    creatorContract,
    0.01 ether,  // basePrice
    0.001 ether  // increment
);

// Option 2: Use separate price engine (requires adapter that implements both interfaces)
LinearBondingCurvePriceEngine priceEngine = new LinearBondingCurvePriceEngine(
    0.01 ether,
    0.001 ether
);
```

### On-Chain Art

```solidity
// Deploy art generator
GenerativePolygonArt art = new GenerativePolygonArt(creatorContract);

// Register as extension
ICreatorCore(creatorContract).registerExtension(address(art), "");

// Mint tokens - each will have unique art generated
art.mint(to);
```

## Security Notes

⚠️ **Important**: The `setAuthorizedMarketplace()` function in the adapters currently allows any caller. In production, you must add proper access control (e.g., only creator contract owner can authorize).

## Testing

These contracts are designed to work with the auctionhouse marketplace. Test them thoroughly before deploying to mainnet:

1. Deploy adapter/price engine/art contract
2. Register adapter as extension on Creator Core
3. Authorize marketplace address
4. Create test listing
5. Verify minting and pricing work correctly

## License

MIT


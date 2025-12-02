# On-Chain Art Examples

This directory contains example contracts for generating on-chain art using SVG and GLSL-inspired effects.

## Art Contracts

### GenerativePolygonArt
Generates unique geometric polygon art with animated gradients and rotations. Each token produces a unique polygon pattern based on token ID and owner address.

**Features:**
- Procedurally generated polygon shapes (3-8 sides)
- Radial gradients with animated rotation
- Unique color schemes per token
- Deterministic generation based on token ID and owner

### WaveInterferenceArt
Creates wave interference patterns using SVG filters that simulate GLSL shader effects. Features animated wave patterns with interference.

**Features:**
- SVG turbulence filters for wave generation
- Color gradients with hue rotation
- Multiple overlapping wave layers
- Smooth animations

### FractalArt
Generates fractal-like patterns using SVG filters and gradients. Creates recursive geometric patterns with procedural generation.

**Features:**
- Turbulence-based fractal generation
- Multiple octave layers for complexity
- Animated scaling and rotation
- Radial gradient color schemes

### PlasmaArt
Creates plasma-like effects using SVG filters that simulate GLSL shader techniques. Features animated plasma patterns with color shifts.

**Features:**
- Turbulence-based plasma generation
- Animated base frequency changes
- Hue rotation for color effects
- Component transfer for intensity control

## Usage

These contracts are Creator Core extensions that must be registered with a Creator Core contract:

```solidity
// Deploy art contract
GenerativePolygonArt art = new GenerativePolygonArt(creatorContractAddress);

// Register as extension
ICreatorCore(creatorContract).registerExtension(address(art), "");

// Mint tokens
art.mint(to);
```

## Integration with Auctionhouse

These art contracts can be used with the auctionhouse marketplace:

**Standard Sales:**
```solidity
// Mint token
art.mint(seller);

// Transfer to marketplace
IERC721(creatorContract).transferFrom(seller, marketplace, tokenId);

// Create listing
// ... standard listing creation
```

**Lazy Minting:**
Combine with ERC721CreatorLazyDelivery adapter:

```solidity
// Deploy adapter
ERC721CreatorLazyDelivery adapter = new ERC721CreatorLazyDelivery(creatorContract);

// Register adapter
ICreatorCore(creatorContract).registerExtension(address(adapter), "");

// Register art contract
ICreatorCore(creatorContract).registerExtension(address(art), "");

// Authorize marketplace
adapter.setAuthorizedMarketplace(marketplaceAddress, true);

// Create lazy listing
// Token will be minted with art when purchased
```

## Technical Details

All art contracts:
- Implement `ICreatorExtensionTokenURI` to generate SVG on-chain
- Use tag-based replacement system for efficient SVG generation
- Generate deterministic art based on token ID and owner address
- Support animated SVG with transform and attribute animations
- Use SVG filters to simulate GLSL shader effects

## Customization

Each contract can be customized by:
- Modifying the SVG template in `_initializeSVGTemplate()`
- Adjusting parameter ranges in `tokenURI()`
- Adding new tags and replacement logic
- Changing color schemes and animation timings

## License

MIT


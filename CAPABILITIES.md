# Auctionhouse Contracts Capabilities

## 1. Introduction

The Auctionhouse Contracts is a comprehensive marketplace system for selling NFTs and other digital assets. It is a fork of the [Manifold Gallery](https://gallery.manifold.xyz) Auctionhouse contracts, written for the [Cryptoart](https://warpcast.com/~/channel/cryptoart) channel on Farcaster.

### Key Differences from Original

- **Membership-Based Seller Registry**: The seller registry is linked to active hypersub membership (STP v2 NFT's `balanceOf` function returns time-remaining)

### Architecture Overview

The system is built with a modular architecture:

- **MarketplaceCore**: Core abstract contract containing all marketplace logic
- **MarketplaceUpgradeable**: Upgradeable implementation using UUPS proxy pattern
- **MarketplaceLib**: Library containing listing construction and validation logic
- **SettlementLib**: Library handling all payment and settlement logic
- **TokenLib**: Library providing token transfer utilities for ERC721 and ERC1155

This architecture allows for:
- Upgradeable contracts for bug fixes and feature additions
- Reusable library code
- Clear separation of concerns

## 2. Listing Types

The auctionhouse supports four distinct listing types, each designed for different sales scenarios:

### 2.1 INDIVIDUAL_AUCTION

Traditional single-item auctions with competitive bidding.

**Characteristics:**
- One token per listing (`totalAvailable` must equal `totalPerSale`)
- Supports ERC721 and ERC1155 tokens (non-lazy only)
- Buyers place bids instead of direct purchases
- Highest bidder wins when auction ends
- Can optionally accept offers (if enabled and no bids have been placed)

**Configuration Options:**
- `initialAmount`: Reserve price (minimum bid)
- `minIncrementBPS`: Minimum bid increase percentage (basis points)
- `extensionInterval`: If a bid is placed within this many seconds before auction end, extend auction by this duration
- `startTime`: Auction start time (0 = starts on first bid)
- `endTime`: Auction end time (if startTime is 0, represents duration from first bid)

**Lifecycle:**
1. Listing created with token in escrow
2. Bidders place bids (must meet minimum increment)
3. Auction extends if bid placed within `extensionInterval` of end
4. Seller or buyer calls `finalize()` after auction ends
5. Highest bidder receives token, seller receives payment

**Constraints:**
- Cannot be lazy minted
- Must have `totalAvailable == totalPerSale`
- Cannot accept offers once a bid has been placed

### 2.2 FIXED_PRICE

Direct purchase listings at a set price. Buyers can purchase immediately without bidding.

**Characteristics:**
- Supports multiple purchases (multi-edition)
- Supports ERC721 and ERC1155 tokens (non-lazy only)
- Immediate purchase at fixed price
- Multiple buyers can purchase until supply runs out

**Configuration Options:**
- `initialAmount`: Fixed purchase price
- `totalAvailable`: Total number of tokens available
- `totalPerSale`: Number of tokens per purchase
- `startTime`: Sale start time (0 = starts on first purchase)
- `endTime`: Sale end time (if startTime is 0, represents duration from first purchase)

**Lifecycle:**
1. Listing created with tokens in escrow
2. Buyers call `purchase()` with exact amount
3. Tokens transferred immediately on purchase
4. Listing auto-finalizes when all tokens sold

**Constraints:**
- Cannot be lazy minted
- Cannot use `extensionInterval` or `minIncrementBPS`
- Cannot have delivery fees

### 2.3 DYNAMIC_PRICE

Price changes based on sales progress. Perfect for bonding curves, Dutch auctions, or time-based pricing.

**Characteristics:**
- Price determined by `IPriceEngine` contract
- Supports lazy minting only
- Price adjusts based on `alreadyMinted` count
- Enables sophisticated pricing mechanisms

**Configuration Options:**
- `initialAmount`: Must be 0 (price comes from IPriceEngine)
- `totalAvailable`: Total supply available
- `totalPerSale`: Typically 1 (required for lazy mints)
- Token contract must implement `IPriceEngine`
- No reserve price or increment requirements

**Price Engine Interface:**
```solidity
function price(uint256 assetId, uint256 alreadyMinted, uint24 count) view external returns (uint256);
```

**Lifecycle:**
1. Listing created with lazy delivery configured
2. Buyers call `purchase()` with payment (may send excess, refunded)
3. `IPriceEngine.price()` called to determine current price
4. Token lazy-minted via `ILazyDelivery.deliver()`
5. Payment settled at calculated price

**Constraints:**
- Must be lazy minted
- Requires `IPriceEngine` implementation
- `initialAmount` must be 0
- Cannot use `extensionInterval` or `minIncrementBPS`
- Cannot have delivery fees

### 2.4 OFFERS_ONLY

Listing where sellers accept offers from buyers. No direct purchase option.

**Characteristics:**
- Buyers make offers
- Seller chooses which offers to accept
- Supports multiple offers simultaneously
- Offers can be rescinded by buyers (with restrictions)

**Configuration Options:**
- `initialAmount`: Must be 0
- `startTime`: Must be in the future
- `endTime`: Offer acceptance deadline
- Buyers make offers, seller accepts via `accept()`

**Lifecycle:**
1. Listing created (token can be lazy or non-lazy)
2. Buyers call `offer()` with their offer amount
3. Funds held in escrow
4. Seller calls `accept()` to accept specific offers
5. Accepted offers: tokens delivered, payment settled
6. Unaccepted offers can be rescinded after listing ends + 24 hours

**Offer Rescinding Rules:**
- For OFFERS_ONLY listings: Can only rescind after listing finalized OR 24 hours after end time
- For auction listings with offers enabled: Can rescind anytime before bid is placed

**Constraints:**
- `initialAmount` must be 0
- `startTime` must be in the future
- Cannot use `extensionInterval` or `minIncrementBPS`
- Cannot have delivery fees

## 3. Token Support

### 3.1 ERC721 Support

Single, unique tokens (1/1 NFTs).

**Usage:**
- `INDIVIDUAL_AUCTION`: One ERC721 token per auction
- `FIXED_PRICE`: Can sell multiple copies if contract supports multiple token IDs
- `totalPerSale`: Must be 1
- Tokens transferred via `transferFrom()`

**Intake Mechanism:**
- Token must be approved and transferred to marketplace contract
- Marketplace holds token in escrow until sale completes

### 3.2 ERC1155 Support

Multi-edition tokens (editions/multiples).

**Usage:**
- `FIXED_PRICE`: Can sell editions (e.g., 100 copies)
- `totalAvailable`: Total supply of the edition
- `totalPerSale`: Number of editions per purchase (e.g., 1, 5, 10)
- Tokens transferred via `safeTransferFrom()`

**Example:** Selling 100 copies where each purchase gives 1 copy:
- `totalAvailable`: 100
- `totalPerSale`: 1
- Buyers can purchase until all 100 are sold

**Intake Mechanism:**
- Entire `totalAvailable` amount must be transferred to marketplace initially
- Marketplace distributes tokens per purchase

### 3.3 Lazy Minting Support

Tokens minted on-demand at purchase time via `ILazyDelivery` interface.

**When to Use:**
- `DYNAMIC_PRICE`: Required for dynamic pricing
- `OFFERS_ONLY`: Can use lazy minting
- Any listing where you want to mint at purchase time

**LazyDelivery Interface:**
```solidity
function deliver(
    uint40 listingId,
    address to,
    uint256 assetId,
    uint24 payableCount,
    uint256 payableAmount,
    address payableERC20,
    uint256 index
) external;
```

**Requirements:**
- Token contract must implement `ILazyDelivery`
- `totalPerSale` must be 1
- Seller never transfers token upfront
- Token minted when `deliver()` is called

**Benefits:**
- No upfront token transfer
- Enables dynamic pricing
- Lower gas costs for sellers
- Supports on-demand minting with attributes

## 4. Payment Options

### 4.1 Native ETH Payments

Default payment method using native blockchain currency.

**Usage:**
- Set `erc20` field to `address(0)` in `ListingDetails`
- Buyers send ETH with `purchase()`, `bid()`, or `offer()` calls
- Exact amount validation (except DYNAMIC_PRICE which allows excess)

**Payment Flow:**
1. Buyer sends ETH with transaction
2. Contract validates amount matches listing price
3. ETH held in contract escrow
4. Settlement distributes ETH to seller and fee recipients

### 4.2 ERC20 Token Payments

Alternative payment using any ERC20 token.

**Usage:**
- Set `erc20` field to token contract address in `ListingDetails`
- Buyers must approve marketplace contract first
- Contract uses `transferFrom()` to collect payment

**Supported Tokens:**
- Any ERC20-compliant token
- USDC, USDT, DAI, etc.
- Custom tokens

**Payment Flow:**
1. Buyer approves marketplace contract
2. Buyer calls `purchase()`, `bid()`, or `offer()` with `msg.value = 0`
3. Contract calls `transferFrom()` to collect tokens
4. Settlement distributes tokens to seller and fee recipients

### 4.3 Payment Validation and Settlement

**Validation:**
- FIXED_PRICE: Exact amount required
- INDIVIDUAL_AUCTION: Bid must meet minimum increment
- DYNAMIC_PRICE: Allows excess payment (refunded)
- OFFERS_ONLY: Any amount accepted

**Settlement Distribution:**
1. Marketplace fee (if configured)
2. Referrer fee (if referrer provided)
3. Royalties (if seller is not token creator)
4. Seller/receivers (remaining proceeds)

## 5. Advanced Features

### 5.1 Bidding System

Comprehensive auction bidding with multiple features.

**Reserve Prices:**
- `initialAmount` serves as minimum bid/reserve price
- First bid must meet or exceed reserve
- If no bids meet reserve, seller can cancel

**Minimum Increments:**
- `minIncrementBPS`: Percentage-based minimum bid increase
- Example: 500 BPS = 5% minimum increase
- If 0, minimum increase is 1 wei

**Auction Extensions:**
- `extensionInterval`: Seconds before end time
- If bid placed within extension interval, auction extends
- Prevents last-second sniping
- Extension duration equals `extensionInterval`

**Bid Refunds:**
- Previous bidder automatically refunded when outbid
- Refunds use escrow system if direct transfer fails
- Escrowed funds can be withdrawn via `withdrawEscrow()`

### 5.2 Offers System

Flexible offer mechanism for auctions and OFFERS_ONLY listings.

**When Offers Are Available:**
- `OFFERS_ONLY` listings: Always enabled
- `INDIVIDUAL_AUCTION`: Enabled if `acceptOffers` flag set AND no bids placed

**Making Offers:**
- Buyers call `offer()` with amount
- Funds held in escrow
- Multiple offers can exist simultaneously
- Buyers can increase existing offers

**Accepting Offers:**
- Seller calls `accept()` with offer addresses and amounts
- Can accept multiple offers at once
- Seller can accept partial amount (via `maxAmount` parameter)
- Accepted offers: tokens delivered, payments settled

**Rescinding Offers:**
- Buyers can rescind their own offers
- OFFERS_ONLY: Only after listing finalized OR 24 hours after end time
- Auction offers: Can rescind anytime before bid placed
- Seller can rescind others' offers (after listing ends)

### 5.3 Multi-Receiver Splits

Distribute sale proceeds to multiple recipients.

**Configuration:**
```solidity
ListingReceiver[] receivers = [
    { receiver: address1, receiverBPS: 3000 },  // 30%
    { receiver: address2, receiverBPS: 4000 },  // 40%
    { receiver: address3, receiverBPS: 3000 }   // 30%
];
```

**Requirements:**
- All receiver BPS must sum to exactly 10000 (100%)
- Can have any number of receivers
- Seller receives portion if not in receivers list

**Use Cases:**
- Revenue sharing with collaborators
- Split payments to multiple wallets
- Automatic distribution to DAO treasury
- Artist/curator splits

### 5.4 Referrer System

Optional referral fees to incentivize discovery.

**Configuration:**
- Set `enableReferrer = true` when creating listing
- `referrerBPS` set globally by marketplace admin
- Referrer address passed in purchase/bid/offer calls

**Payment Flow:**
- Referrer receives percentage of sale price
- Deducted from seller proceeds
- Separate from marketplace fees

**Example:**
- Sale price: 1 ETH
- Referrer BPS: 200 (2%)
- Referrer receives: 0.02 ETH
- Seller receives: 0.98 ETH (minus marketplace fees)

### 5.5 Identity Verification

Access control via `IIdentityVerifier` interface.

**Interface:**
```solidity
function verify(
    uint40 listingId,
    address identity,
    address tokenAddress,
    uint256 tokenId,
    uint24 requestCount,
    uint256 requestAmount,
    address requestERC20,
    bytes calldata data
) external returns (bool);
```

**Use Cases:**
- Whitelist-based sales
- KYC/AML compliance
- Token-gated access
- Custom permission logic

**Implementation:**
- Set `identityVerifier` address in `ListingDetails`
- Called before every purchase, bid, or offer
- Must return `true` for transaction to proceed

### 5.6 Delivery Fees

Additional fees required to deliver tokens (auctions only).

**Configuration:**
```solidity
DeliveryFees {
    deliverBPS: 100,      // 1% of sale price
    deliverFixed: 100000  // 0.0001 ETH fixed fee
}
```

**Usage:**
- Only applicable to `INDIVIDUAL_AUCTION` listings
- Buyer pays delivery fee when finalizing auction
- Fee distributed to seller/receivers (not marketplace)

**Example:**
- Auction price: 1 ETH
- Delivery fee: 1% + 0.0001 ETH
- Buyer pays: 1.01 ETH + 0.0001 ETH = 1.0101 ETH total

### 5.7 Royalty Support

Automatic royalty distribution via RoyaltyEngineV1.

**Integration:**
- Marketplace configured with RoyaltyEngineV1 address
- Royalties fetched via `getRoyalty()` call
- Automatically distributed on sale

**Royalty Logic:**
- Only paid if seller is NOT token creator
- Royalties deducted from seller proceeds
- Supports multiple royalty recipients
- Handles ERC2981 and other royalty standards

**Exclusions:**
- Lazy minted tokens: No royalties (minted at sale time)
- Token creator sales: No royalties (creator already owns)

### 5.8 Seller Registry

Optional seller authorization via `IMarketplaceSellerRegistry`.

**Available Registries:**

| Registry | Model | Use Case |
|----------|-------|----------|
| `OpenSellerRegistry` | Allow-all with blocklist | Open marketplace, block bad actors |
| `MembershipSellerRegistry` | Membership required | Members-only marketplace |
| `MembershipAllowlistRegistry` | Membership + associated wallets | Members can associate other wallets |

**OpenSellerRegistry (Recommended for open marketplaces):**
- Everyone can sell by default
- Owner can blocklist specific addresses
- Blocklisted addresses cannot create listings
- Gas efficient single mapping lookup

**MembershipSellerRegistry:**
- Checks if seller holds membership NFT
- Uses `balanceOf()` to verify membership
- Supports STP v2 NFTs (time-based membership)

**MembershipAllowlistRegistry:**
- Membership holders can sell
- Membership holders can associate additional wallets (e.g., Farcaster verified)
- Associated wallets can sell if membership holder still has active membership

**Custom Registry:**
- Implement `IMarketplaceSellerRegistry` interface
- Return `true` in `isAuthorized()` for approved sellers
- Enables custom seller verification logic

**Registries:**
- None: Anyone can list (if marketplace enabled)
- Membership registry: Only NFT holders can list
- Custom: Implement your own verification

## 6. Listing Lifecycle

### 6.1 Creating Listings

**Function:** `createListing()`

**Parameters:**
- `listingDetails`: Listing configuration (type, pricing, timing)
- `tokenDetails`: Token to sell (address, ID, spec, lazy flag)
- `deliveryFees`: Delivery fee configuration (auctions only)
- `listingReceivers`: Revenue split recipients (optional)
- `enableReferrer`: Enable referrer fees
- `acceptOffers`: Enable offers on auctions
- `data`: Additional data for seller registry/identity verifier

**Process:**
1. Validate listing configuration
2. Check seller authorization (if registry set)
3. Transfer tokens to marketplace (if not lazy)
4. Create listing record
5. Emit `CreateListing` event
6. Return listing ID

**Roles:** Seller

### 6.2 Modifying Listings

**Function:** `modifyListing()`

**Parameters:**
- `listingId`: Listing to modify
- `initialAmount`: New reserve price
- `startTime`: New start time
- `endTime`: New end time

**Constraints:**
- Only seller can modify
- Cannot modify if listing has started/completed
- For auctions: Cannot modify if bid placed
- For fixed price: Cannot modify if any sales occurred
- Dynamic price: Cannot change `initialAmount` (must be 0)

**Use Cases:**
- Extend auction duration
- Adjust reserve price
- Delay start time

**Roles:** Seller

### 6.3 Purchasing

**Function:** `purchase()`

**Overloads:**
- `purchase(listingId)` - Purchase 1 item
- `purchase(listingId, count)` - Purchase multiple items
- `purchase(referrer, listingId)` - With referrer
- `purchase(referrer, listingId, count)` - With referrer and count
- All variants support optional `data` parameter

**Process:**
1. Validate listing is purchasable
2. Check identity verification (if configured)
3. Transfer payment from buyer
4. Deliver tokens (direct or lazy)
5. Settle payment (distribute proceeds)
6. Emit `PurchaseEvent`
7. Auto-finalize if all sold

**Roles:** Buyer

### 6.4 Bidding

**Function:** `bid()`

**Overloads:**
- `bid(listingId, increase)` - Place/increase bid
- `bid(listingId, amount, increase)` - Bid specific amount
- `bid(referrer, listingId, increase)` - With referrer
- `bid(referrer, listingId, amount, increase)` - Full options
- All variants support optional `data` parameter

**Process:**
1. Validate auction requirements
2. Check minimum bid increment
3. Refund previous bidder (if any)
4. Accept new bid
5. Extend auction if needed
6. Emit `BidEvent`

**Roles:** Bidder

### 6.5 Making Offers

**Function:** `offer()`

**Overloads:**
- `offer(listingId, increase)` - Make/increase offer
- `offer(listingId, amount, increase)` - Offer specific amount
- `offer(referrer, listingId, increase)` - With referrer
- All variants support optional `data` parameter

**Process:**
1. Validate offers are allowed
2. Check identity verification (if configured)
3. Transfer offer amount to escrow
4. Update or create offer record
5. Emit `OfferEvent`

**Roles:** Buyer

### 6.6 Accepting Offers

**Function:** `accept()`

**Parameters:**
- `listingId`: Listing with offers
- `addresses`: Array of offer addresses to accept
- `amounts`: Expected amounts (for validation)
- `maxAmount`: Maximum to accept (for partial acceptance)

**Process:**
1. Validate seller owns listing
2. Validate offers exist and match expected amounts
3. Finalize listing
4. Deliver tokens to offerers
5. Settle payments
6. Emit `AcceptOfferEvent` for each

**Roles:** Seller

### 6.7 Rescinding Offers

**Function:** `rescind()`

**Overloads:**
- `rescind(listingId)` - Rescind caller's offer
- `rescind(listingIds[])` - Rescind caller's offers on multiple listings
- `rescind(listingId, addresses[])` - Seller rescinds others' offers

**Constraints:**
- OFFERS_ONLY: Only after finalized OR 24 hours after end
- Auction offers: Anytime before bid placed
- Seller can rescind others' offers after listing ends

**Process:**
1. Validate rescind conditions
2. Remove offer from storage
3. Refund offer amount
4. Emit `RescindOfferEvent`

**Roles:** Buyer or Seller

### 6.8 Finalizing Auctions

**Function:** `finalize()`

**Process:**
1. Validate auction has ended
2. Mark listing as finalized
3. If no bids: Return token to seller (if not lazy)
4. If bid exists: Deliver token to highest bidder, settle payment
5. Emit `FinalizeListing` event

**Roles:** Seller or Buyer

**Note:** For auctions with tokens in escrow, seller can call `collect()` to get paid before finalizing.

### 6.9 Collecting Proceeds

**Function:** `collect()`

**Process:**
1. Validate auction has ended
2. Validate token is in escrow (not lazy)
3. Validate bid exists and not settled
4. Settle bid payment to seller
5. Token remains in escrow until `finalize()`

**Use Cases:**
- Seller wants payment before delivering token
- Split payment and delivery transactions

**Roles:** Seller

### 6.10 Canceling Listings

**Function:** `cancel()`

**Parameters:**
- `listingId`: Listing to cancel
- `holdbackBPS`: Percentage to holdback (admin only, max 10%)

**Constraints:**
- Seller: Can cancel if no bids/sales and no holdback
- Admin: Can cancel anytime with optional holdback

**Process:**
1. Validate cancellation allowed
2. End and finalize listing
3. Refund bids (with holdback if admin)
4. Return unsold tokens to seller
5. Emit `CancelListing` event

**Roles:** Seller or Admin

## 7. Configuration & Administration

### 7.1 Marketplace Fees

**Functions:**
- `setFees(marketplaceFeeBPS, marketplaceReferrerBPS)`

**Configuration:**
- `marketplaceFeeBPS`: Marketplace fee percentage (max 15%)
- `referrerBPS`: Referrer fee percentage (max 15%)

**Fee Collection:**
- Marketplace fees accumulated in `_feesCollected` mapping
- Can withdraw via `withdraw()`
- Applied to all sales

**Roles:** Admin

### 7.2 Marketplace Enable/Disable

**Function:**
- `setEnabled(enabled)`

**Effect:**
- `true`: All listings allowed
- `false`: No new listings, existing listings continue

**Roles:** Admin

### 7.3 Seller Registry

**Function:**
- `setSellerRegistry(registry)`

**Registry:**
- Must implement `IMarketplaceSellerRegistry`
- `address(0)`: No registry (anyone can list)
- Non-zero: Only authorized sellers can list

**Roles:** Admin

### 7.4 Royalty Engine

**Function:**
- `setRoyaltyEngineV1(royaltyEngineV1)`

**Configuration:**
- Set once (cannot be changed)
- Address of RoyaltyEngineV1 contract
- Used for royalty lookups

**Roles:** Admin

### 7.5 Withdrawal Functions

**Treasury Withdrawal:**
- `withdraw(amount, receiver)` - Withdraw ETH
- `withdraw(erc20, amount, receiver)` - Withdraw ERC20

**Escrow Withdrawal:**
- `withdrawEscrow(amount)` - Withdraw ETH from escrow
- `withdrawEscrow(erc20, amount)` - Withdraw ERC20 from escrow

**Roles:** 
- Treasury: Admin only
- Escrow: Owner of escrowed funds

## 8. Key Data Structures

### 8.1 Listing Struct

```solidity
struct Listing {
    uint40 id;
    address payable seller;
    bool finalized;
    uint24 totalSold;
    uint16 marketplaceBPS;
    uint16 referrerBPS;
    ListingDetails details;
    TokenDetails token;
    ListingReceiver[] receivers;
    DeliveryFees fees;
    Bid bid;
    bool offersAccepted;
}
```

**Fields:**
- `id`: Unique listing identifier
- `seller`: Address selling the token
- `finalized`: Whether listing is completed
- `totalSold`: Total tokens sold (not number of sales)
- `marketplaceBPS`: Marketplace fee percentage
- `referrerBPS`: Referrer fee percentage
- `details`: Listing configuration
- `token`: Token being sold
- `receivers`: Revenue split recipients
- `fees`: Delivery fee configuration
- `bid`: Current highest bid (auctions only)
- `offersAccepted`: Whether offers are enabled

### 8.2 ListingDetails Struct

```solidity
struct ListingDetails {
    uint256 initialAmount;
    ListingType type_;
    uint24 totalAvailable;
    uint24 totalPerSale;
    uint16 extensionInterval;
    uint16 minIncrementBPS;
    address erc20;
    address identityVerifier;
    uint48 startTime;
    uint48 endTime;
}
```

**Fields:**
- `initialAmount`: Reserve price or fixed price
- `type_`: Listing type enum
- `totalAvailable`: Total tokens available
- `totalPerSale`: Tokens per purchase
- `extensionInterval`: Auction extension seconds
- `minIncrementBPS`: Minimum bid increment percentage
- `erc20`: Payment token (0 = ETH)
- `identityVerifier`: Access control contract
- `startTime`: Start timestamp (0 = on first action)
- `endTime`: End timestamp

### 8.3 TokenDetails Struct

```solidity
struct TokenDetails {
    uint256 id;
    address address_;
    TokenLib.Spec spec;
    bool lazy;
}
```

**Fields:**
- `id`: Token ID or asset ID
- `address_`: Token contract address
- `spec`: ERC721 or ERC1155
- `lazy`: Whether lazy minted

### 8.4 Bid Struct

```solidity
struct Bid {
    uint256 amount;
    address payable bidder;
    bool delivered;
    bool settled;
    bool refunded;
    uint48 timestamp;
    address payable referrer;
}
```

**Fields:**
- `amount`: Bid amount
- `bidder`: Bidder address
- `delivered`: Token delivered flag
- `settled`: Payment settled flag
- `refunded`: Refunded flag
- `timestamp`: Bid timestamp
- `referrer`: Referrer address

### 8.5 Offer Struct

```solidity
struct Offer {
    uint200 amount;
    uint48 timestamp;
    bool accepted;
    address payable referrer;
    address erc20;
}
```

**Fields:**
- `amount`: Offer amount (max 2^200-1)
- `timestamp`: Offer timestamp
- `accepted`: Accepted flag
- `referrer`: Referrer address
- `erc20`: Currently unused

### 8.6 DeliveryFees Struct

```solidity
struct DeliveryFees {
    uint16 deliverBPS;
    uint240 deliverFixed;
}
```

**Fields:**
- `deliverBPS`: Percentage-based fee
- `deliverFixed`: Fixed fee amount

### 8.7 ListingReceiver Struct

```solidity
struct ListingReceiver {
    address payable receiver;
    uint16 receiverBPS;
}
```

**Fields:**
- `receiver`: Recipient address
- `receiverBPS`: Percentage share (must sum to 10000)

## 9. Integrations & Extensions

### 9.1 ILazyDelivery Interface

**Purpose:** Enable lazy minting of tokens at purchase time.

**Interface:**
```solidity
interface ILazyDelivery is IERC165 {
    function deliver(
        uint40 listingId,
        address to,
        uint256 assetId,
        uint24 payableCount,
        uint256 payableAmount,
        address payableERC20,
        uint256 index
    ) external;
}
```

**Implementation Requirements:**
- Token contract must implement this interface
- Called by marketplace when token needs delivery
- Should mint and transfer token to `to` address
- Can use `listingId` for permissioning

**Example Use Cases:**
- Mint NFT with purchase
- Assign attributes based on purchase order
- On-demand token creation

### 9.2 IPriceEngine Interface

**Purpose:** Determine dynamic pricing based on sales progress.

**Interface:**
```solidity
interface IPriceEngine is IERC165 {
    function price(
        uint256 assetId,
        uint256 alreadyMinted,
        uint24 count
    ) view external returns (uint256);
}
```

**Parameters:**
- `assetId`: Asset identifier
- `alreadyMinted`: Number already sold
- `count`: Number being purchased

**Return:**
- Price in wei (or token units if ERC20)

**Price Models:**
- Linear bonding curve
- Exponential curve
- Dutch auction (decreasing)
- Step pricing

**Implementation Requirements:**
- Must be view function
- Must return price for given parameters
- Should be consistent (same inputs = same output)

### 9.3 IIdentityVerifier Interface

**Purpose:** Access control for purchases, bids, and offers.

**Interface:**
```solidity
interface IIdentityVerifier is IERC165 {
    function verify(
        uint40 listingId,
        address identity,
        address tokenAddress,
        uint256 tokenId,
        uint24 requestCount,
        uint256 requestAmount,
        address requestERC20,
        bytes calldata data
    ) external returns (bool);
}
```

**Parameters:**
- `listingId`: Listing identifier
- `identity`: Buyer/bidder address
- `tokenAddress`: Token contract
- `tokenId`: Token ID
- `requestCount`: Items requested
- `requestAmount`: Payment amount
- `requestERC20`: Payment token
- `data`: Additional verification data

**Return:**
- `true` if authorized, `false` otherwise

**Implementation Ideas:**
- NFT whitelist checking
- Signature verification
- KYC integration
- Custom logic

### 9.4 IMarketplaceSellerRegistry Interface

**Purpose:** Control who can create listings.

**Interface:**
```solidity
interface IMarketplaceSellerRegistry is IERC165 {
    function isAuthorized(
        address seller,
        bytes calldata data
    ) external view returns(bool);
}
```

**Implementation:**
- `OpenSellerRegistry`: Allows everyone, owner-managed blocklist
- `MembershipSellerRegistry`: Checks NFT balance
- `MembershipAllowlistRegistry`: Membership + associated wallets
- Custom registries: Implement your own logic

**Use Cases:**
- Membership-gated listings
- DAO-only listings
- Verified seller program

### 9.5 RoyaltyEngineV1 Integration

**Purpose:** Standard royalty lookup and distribution.

**Integration:**
- Marketplace calls `getRoyalty()` on RoyaltyEngineV1
- Returns recipients and amounts
- Marketplace distributes automatically

**Supported Standards:**
- ERC2981
- Custom royalty implementations

**Royalty Logic:**
- Only paid if seller is not token creator
- Deducted from seller proceeds
- Multiple recipients supported

## 10. Security Features

### 10.1 Reentrancy Protection

**Mechanism:**
- `ReentrancyGuardUpgradeable` on critical functions
- `nonReentrant` modifier on state-changing operations

**Protected Functions:**
- `purchase()`
- `bid()`
- `offer()`
- `finalize()`
- `cancel()`
- `withdraw()`

**Prevention:**
- Prevents recursive calls during state changes
- Ensures atomic operations

### 10.2 Escrow System

**Purpose:** Handle failed token transfers gracefully.

**Mechanism:**
- Failed refunds stored in escrow mapping
- Users can withdraw via `withdrawEscrow()`
- Prevents permanent fund loss

**Use Cases:**
- Contract wallets that reject transfers
- Gas limit issues
- Token contract issues

### 10.3 Admin Controls

**Access Control:**
- `AdminControlUpgradeable` for admin functions
- `OwnableUpgradeable` for ownership
- Separate admin and owner roles

**Admin Functions:**
- Fee configuration
- Marketplace enable/disable
- Seller registry setting
- Treasury withdrawal
- Cancel listings (with holdback)

**Owner Functions:**
- Admin management
- Ownership transfer

### 10.4 Access Control Mechanisms

**Seller Authorization:**
- Seller registry check on listing creation
- Optional membership verification

**Buyer Authorization:**
- Identity verifier on purchases/bids/offers
- Custom permission logic

**Modification Authorization:**
- Only seller can modify listing
- Only seller can finalize (unless ended)
- Only seller can accept offers

## 11. Examples & Use Cases

### 11.1 Basic 1/1 Auction

**Scenario:** Artist selling a single NFT via auction.

```solidity
// Listing details
ListingDetails memory details = ListingDetails({
    initialAmount: 0.1 ether,           // Reserve: 0.1 ETH
    type_: ListingType.INDIVIDUAL_AUCTION,
    totalAvailable: 1,
    totalPerSale: 1,
    extensionInterval: 300,            // 5 min extension
    minIncrementBPS: 500,              // 5% minimum increase
    erc20: address(0),                 // ETH payment
    identityVerifier: address(0),       // No restrictions
    startTime: block.timestamp,        // Start now
    endTime: block.timestamp + 7 days   // 7 day auction
});

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: nftContract,
    spec: TokenLib.Spec.ERC721,
    lazy: false
});

// Create listing
uint40 listingId = marketplace.createListing(
    details,
    token,
    DeliveryFees({deliverBPS: 0, deliverFixed: 0}),
    new ListingReceiver[](0),  // No splits
    false,  // No referrer
    false,  // No offers
    ""
);
```

### 11.2 Multi-Edition Fixed Price Sale

**Scenario:** Selling 100 editions at fixed price.

```solidity
ListingDetails memory details = ListingDetails({
    initialAmount: 0.05 ether,        // 0.05 ETH per edition
    type_: ListingType.FIXED_PRICE,
    totalAvailable: 100,               // 100 editions
    totalPerSale: 1,                   // 1 per purchase
    extensionInterval: 0,              // Not applicable
    minIncrementBPS: 0,                // Not applicable
    erc20: address(0),
    identityVerifier: address(0),
    startTime: 0,                      // Start on first purchase
    endTime: 30 days                   // Duration from first purchase
});

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: editionContract,
    spec: TokenLib.Spec.ERC1155,
    lazy: false
});

// Transfer 100 editions to marketplace first
ERC1155(editionContract).safeTransferFrom(
    seller,
    address(marketplace),
    1,  // tokenId
    100, // quantity
    ""
);
```

### 11.3 Dynamic Price Bonding Curve

**Scenario:** Price increases with each sale.

```solidity
// PriceEngine contract
contract BondingCurvePriceEngine is IPriceEngine {
    function price(uint256 assetId, uint256 alreadyMinted, uint24 count) 
        external pure override returns (uint256) {
        // Linear: price = basePrice + (alreadyMinted * increment)
        uint256 basePrice = 0.01 ether;
        uint256 increment = 0.001 ether;
        return basePrice + (alreadyMinted * increment);
    }
}

// Listing details
ListingDetails memory details = ListingDetails({
    initialAmount: 0,                  // Must be 0
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
    address_: lazyMintContract,        // Must implement ILazyDelivery
    spec: TokenLib.Spec.ERC721,
    lazy: true                         // Required for dynamic price
});
```

### 11.4 Offers-Only Listing

**Scenario:** Seller wants to review offers before accepting.

```solidity
ListingDetails memory details = ListingDetails({
    initialAmount: 0,                  // Must be 0
    type_: ListingType.OFFERS_ONLY,
    totalAvailable: 1,
    totalPerSale: 1,
    extensionInterval: 0,
    minIncrementBPS: 0,
    erc20: address(0),
    identityVerifier: address(0),
    startTime: block.timestamp + 1 day, // Must be future
    endTime: block.timestamp + 8 days
});

// Buyers make offers
marketplace.offer{value: 0.5 ether}(listingId, false);
marketplace.offer{value: 0.7 ether}(listingId, false);
marketplace.offer{value: 0.6 ether}(listingId, false);

// Seller accepts best offer
address[] memory addresses = new address[](1);
uint256[] memory amounts = new uint256[](1);
addresses[0] = address(0xBuyer2);  // 0.7 ETH offer
amounts[0] = 0.7 ether;
marketplace.accept(listingId, addresses, amounts, 0);
```

### 11.5 Revenue Split Sale

**Scenario:** Artist wants to split proceeds with collaborator and DAO.

```solidity
ListingReceiver[] memory receivers = new ListingReceiver[](3);
receivers[0] = ListingReceiver({
    receiver: payable(artist),
    receiverBPS: 6000  // 60%
});
receivers[1] = ListingReceiver({
    receiver: payable(collaborator),
    receiverBPS: 2500  // 25%
});
receivers[2] = ListingReceiver({
    receiver: payable(dao),
    receiverBPS: 1500  // 15%
});
// Total: 10000 BPS = 100%

marketplace.createListing(
    details,
    token,
    deliveryFees,
    receivers,  // Revenue split
    false,
    false,
    ""
);
```

### 11.6 Referrer-Enabled Sale

**Scenario:** Marketplace wants to reward referrals.

```solidity
// Enable referrer when creating listing
marketplace.createListing(
    details,
    token,
    deliveryFees,
    receivers,
    true,  // Enable referrer
    false,
    ""
);

// Buyer purchases with referrer
address referrer = address(0xReferrer);
marketplace.purchase{value: price}(referrer, listingId);
// Referrer receives percentage of sale
```

### 11.7 Whitelist Sale

**Scenario:** Only holders of specific NFT can purchase.

```solidity
// IdentityVerifier contract
contract WhitelistVerifier is IIdentityVerifier {
    IERC721 public whitelistNFT;
    
    function verify(
        uint40 listingId,
        address identity,
        address tokenAddress,
        uint256 tokenId,
        uint24 requestCount,
        uint256 requestAmount,
        address requestERC20,
        bytes calldata data
    ) external view override returns (bool) {
        return whitelistNFT.balanceOf(identity) > 0;
    }
}

ListingDetails memory details = ListingDetails({
    // ... other fields
    identityVerifier: address(whitelistVerifier),
    // ...
});
```

### 11.8 ERC20 Payment Sale

**Scenario:** Accepting USDC instead of ETH.

```solidity
ListingDetails memory details = ListingDetails({
    initialAmount: 100 * 10**6,        // 100 USDC (6 decimals)
    type_: ListingType.FIXED_PRICE,
    totalAvailable: 1,
    totalPerSale: 1,
    extensionInterval: 0,
    minIncrementBPS: 0,
    erc20: address(usdcContract),       // USDC address
    identityVerifier: address(0),
    startTime: block.timestamp,
    endTime: block.timestamp + 7 days
});

// Buyer must approve first
IERC20(usdcContract).approve(address(marketplace), 100 * 10**6);
// Then purchase
marketplace.purchase(listingId);
```

### 11.9 Lazy Minting Sale

**Scenario:** Mint NFT only when purchased.

```solidity
// LazyDelivery contract
contract LazyMintNFT is ERC721, ILazyDelivery {
    function deliver(
        uint40 listingId,
        address to,
        uint256 assetId,
        uint24 payableCount,
        uint256 payableAmount,
        address payableERC20,
        uint256 index
    ) external override {
        require(msg.sender == address(marketplace), "Unauthorized");
        // Mint with purchase order as attribute
        uint256 tokenId = totalSupply() + 1;
        _safeMint(to, tokenId);
        // Store attributes if needed
    }
}

TokenDetails memory token = TokenDetails({
    id: 1,
    address_: address(lazyMintContract),
    spec: TokenLib.Spec.ERC721,
    lazy: true  // Enable lazy minting
});
```

### 11.10 Auction with Offers

**Scenario:** Allow offers before first bid, then switch to bidding only.

```solidity
marketplace.createListing(
    details,
    token,
    deliveryFees,
    receivers,
    false,
    true,  // Accept offers
    ""
);

// Buyers can make offers before bidding starts
marketplace.offer{value: 0.5 ether}(listingId, false);

// Once first bid placed, offers disabled
marketplace.bid{value: 0.6 ether}(listingId, false);
// Now only bidding allowed
```

## 12. Important Notes

### 12.1 totalSold vs Number of Sales

`totalSold` represents the **total number of tokens sold**, not the number of sales transactions.

**Example:**
- `totalAvailable`: 100
- `totalPerSale`: 5
- Each purchase sells 5 tokens
- After 10 purchases: `totalSold = 50`
- Number of sales: 10

### 12.2 Time-Based Constraints

**startTime = 0:**
- Listing starts on first action (purchase/bid/offer)
- `endTime` becomes duration from start
- Common for "start whenever" listings

**startTime > 0:**
- Listing starts at specific timestamp
- `endTime` is absolute end time
- Better for scheduled sales

### 12.3 Lazy vs Non-Lazy Tokens

**Non-Lazy (Standard):**
- Seller transfers tokens to marketplace upfront
- Tokens held in escrow
- Marketplace transfers on purchase
- Supports ERC721 and ERC1155

**Lazy Minting:**
- No upfront transfer
- Token minted via `ILazyDelivery.deliver()`
- Required for `DYNAMIC_PRICE` listings
- `totalPerSale` must be 1

### 12.4 Offer System Differences

**Auction Offers:**
- Enabled only if `acceptOffers` flag set AND no bids
- Disabled once first bid placed
- Can rescind anytime before bid

**OFFERS_ONLY Listings:**
- Offers always enabled
- No direct purchase option
- Can rescind after finalized OR 24 hours after end

### 12.5 Gas Considerations

**Optimizations:**
- Lazy minting saves gas (no upfront transfer)
- Batch operations for multiple offers
- ERC20 payments require approval (separate transaction)

**Gas Costs:**
- Creating listing: Higher for non-lazy (includes transfer)
- Purchase: Standard ERC721/1155 transfer costs
- Bidding: Refund costs if outbid
- Offers: Lower (no token transfer until accepted)

## 13. Contract Addresses & Deployment

### 13.1 Main Contracts

- **MarketplaceUpgradeable**: Upgradeable implementation contract
- **OpenSellerRegistry**: Allow-all seller registry with owner-managed blocklist
- **MembershipSellerRegistry**: NFT-based seller registry
- **MembershipAllowlistRegistry**: Membership + associated wallets registry
- **ILazyDelivery**: Interface for lazy minting (implement in your contract)
- **IPriceEngine**: Interface for dynamic pricing (implement in your contract)
- **IIdentityVerifier**: Interface for access control (implement in your contract)

### 13.2 Deployment

Contracts are deployed using Foundry and OpenZeppelin Upgrades:

```bash
forge script script/DeployContracts.s.sol:DeployContractsScript \
    --rpc-url <RPC_URL> \
    --private-key <PRIVATE_KEY> \
    --broadcast
```

Initialize with:
```solidity
marketplace.initialize(initialOwner);
marketplace.setFees(marketplaceFeeBPS, referrerBPS);
marketplace.setSellerRegistry(sellerRegistryAddress);
marketplace.setRoyaltyEngineV1(royaltyEngineV1Address);
```

## 14. Testing

Test suite available in `test/MarketplaceUpgradeable.t.sol`:

```bash
forge test
```

Coverage includes:
- Basic auction functionality
- Fixed price purchases
- Offer system
- Token transfers
- Fee distribution

## 15. References

- **Manifold Gallery**: Original auctionhouse implementation
- **OpenZeppelin**: Upgradeable contracts and security patterns
- **ERC721**: NFT standard
- **ERC1155**: Multi-token standard
- **ERC2981**: Royalty standard


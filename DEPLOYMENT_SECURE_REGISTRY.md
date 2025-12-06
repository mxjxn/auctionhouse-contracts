# MembershipAllowlistRegistrySecure Deployment

## Overview

Deployed a secure version of the membership allowlist registry that requires **signature-based proof of ownership** when associating addresses. This prevents address spoofing attacks where someone could claim to control addresses they don't own.

## Deployment Details

| Field | Value |
|-------|-------|
| **Contract** | `MembershipAllowlistRegistrySecure` |
| **Network** | Base Mainnet |
| **Chain ID** | 8453 |
| **Contract Address** | `0x4C5c5E94393c1359158B3Ba980c1bd5FB502A7bA` |
| **Membership NFT** | `0xb83DFE710F0C42A10468ba3F4be300Fd4c5763EB` |
| **Deployed At Block** | 39105628 |
| **Deploy TX** | `0x1af63d8f3fe1b2fa81b9d409f9251c59052b4d8538b0f072c42b966a5d9a04a5` |
| **Gas Used** | 772,342 |
| **Deployer** | `0x6dA173B1d50F7Bc5c686f8880C20378965408344` |
| **Verified** | ✅ Yes |
| **Basescan** | https://basescan.org/address/0x4c5c5e94393c1359158b3ba980c1bd5fb502a7ba |

## Marketplace Registry Update

| Field | Value |
|-------|-------|
| **Marketplace Proxy** | `0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9` |
| **TX Hash** | `0x78adebadd0c79f7faf6ac58127386855ac38a7f6ca1520a53020fc9491b61c25` |
| **Block** | 39105699 |
| **Status** | ✅ Success |
| **Gas Used** | 40,282 |

## Security Improvements

### Problem with Original Contract
The original `MembershipAllowlistRegistry` allowed any membership holder to associate **any arbitrary address** without that address's consent. This enabled:
- Impersonation attacks (claiming famous artist wallets)
- Security scanner flags for "malicious" behavior
- Trust exploitation

### Solution: Signature-Based Proof of Ownership
The new `MembershipAllowlistRegistrySecure` contract requires:

1. **ECDSA Signature** - The associated address must sign a message consenting to the association
2. **Nonce-based Replay Protection** - Each association uses an incrementing nonce
3. **Chain ID Binding** - Signatures are chain-specific to prevent cross-chain replay
4. **Contract Address Binding** - Signatures are contract-specific
5. **Self-Revocation** - Associated addresses can remove their own association via `removeSelfAssociation()`

## Contract Interface

### New Function Signature
```solidity
function addAssociatedAddress(
    address associatedAddress, 
    bytes calldata signature
) external;
```

### Helper Functions
```solidity
// Get the message hash to sign
function getAssociationMessageHash(
    address membershipHolder,
    address associatedAddress,
    uint256 nonce
) public view returns (bytes32);

// Get current nonce for an address
function nonces(address) public view returns (uint256);

// Associated address can remove themselves
function removeSelfAssociation() external;
```

## Frontend Integration

To associate an address, the frontend must:

```javascript
import { ethers } from 'ethers';

// 1. Get the current nonce
const nonce = await registrySecure.nonces(associatedAddress);

// 2. Build the message hash
const messageHash = await registrySecure.getAssociationMessageHash(
    membershipHolderAddress, 
    associatedAddress, 
    nonce
);

// 3. Have the associated wallet sign it
const signature = await associatedWallet.signMessage(ethers.getBytes(messageHash));

// 4. Membership holder submits the transaction with the signature
await registrySecure.addAssociatedAddress(associatedAddress, signature);
```

## Files Created/Modified

### Smart Contracts (packages/auctionhouse-contracts)
| File | Purpose |
|------|---------|
| `src/MembershipAllowlistRegistrySecure.sol` | Secure contract implementation |
| `test/MembershipAllowlistRegistrySecure.t.sol` | Test suite (37 tests) |
| `script/DeployMembershipAllowlistRegistrySecure.s.sol` | Deployment script |

### Frontend (apps/mvp)
| File | Purpose |
|------|---------|
| `src/lib/contracts/membership-allowlist.ts` | Updated contract address + ABI |
| `src/hooks/useMembershipAllowlist.ts` | Updated hook with signature flow |
| `src/components/MembershipAllowlistManager.tsx` | Updated UI for multi-wallet signing |

## Frontend Flow

The secure contract requires a multi-wallet signature flow:

1. **User sees their Farcaster verified addresses**
2. **To add an address:**
   - Connect the wallet you want to add
   - Click "Sign to Allowlist" - signs consent message
   - Switch to your membership wallet
   - Click "Submit" - sends transaction with signature
3. **Signatures are stored in localStorage** for 1 hour
4. **Self-revocation** - Associated addresses can remove themselves

## Previous Contract (Deprecated)

| Field | Value |
|-------|-------|
| **Contract** | `MembershipAllowlistRegistry` (insecure) |
| **Address** | `0xF190fD214844931a92076aeCB5316f769f4A8483` |
| **Status** | ⚠️ Deprecated - do not use |

## Date

Deployed: December 6, 2025


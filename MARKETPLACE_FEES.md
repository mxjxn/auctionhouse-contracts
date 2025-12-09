# Marketplace Fees - Collection and Withdrawal

## Issue Summary

Marketplace fees (5% = 500 BPS) are being **collected correctly** from sales, but they are **not automatically sent** to the fee recipient address. Instead, fees accumulate in the marketplace contract and must be **manually withdrawn** by an admin.

## How Fees Work

### Fee Collection
- When a sale occurs, the marketplace deducts the configured marketplace fee (5% = 500 BPS)
- Fees are accumulated in the `feesCollected` mapping in the contract
- Fees are stored per token type (ETH = `address(0)`, ERC20 tokens = token address)

### Fee Withdrawal
- Fees are **NOT automatically sent** to the fee recipient
- An admin must call `withdraw()` to transfer accumulated fees
- This is by design - it allows batching withdrawals and reduces gas costs

## Current Status

**Marketplace Proxy (Base Mainnet)**: `0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9`  
**Fee Recipient**: `0x6dA173B1d50F7Bc5c686f8880C20378965408344`  
**Fee Configuration**: 5% (500 BPS)

## Solutions

### Option 1: Check Contract Balance and Withdraw (Works Now)

**Note**: The current contract doesn't expose `feesCollected` publicly, so we check the contract balance instead. If the contract only holds fees, the balance equals accumulated fees.

```bash
# Check contract balance (represents accumulated fees if contract only holds fees)
cast balance 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 --rpc-url https://mainnet.base.org

# Withdraw all ETH from contract (assuming it's all fees)
# Replace AMOUNT_IN_WEI with the balance from above
cast send 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 \
  "withdraw(uint256,address)" \
  AMOUNT_IN_WEI \
  0x6dA173B1d50F7Bc5c686f8880C20378965408344 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

**Example** (if balance is 0.1 ETH = 100000000000000000 wei):
```bash
cast send 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 \
  "withdraw(uint256,address)" \
  100000000000000000 \
  0x6dA173B1d50F7Bc5c686f8880C20378965408344 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

# Withdraw partial amount (in wei)
forge script script/WithdrawFees.s.sol:WithdrawFeesPartial \
  --sig "withdrawFeesPartial(uint256)" 1000000000000000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv

# Withdraw ERC20 fees
forge script script/WithdrawFees.s.sol:WithdrawERC20Fees \
  --sig "withdrawERC20Fees(address,uint256)" 0xTokenAddress 1000000000000000000 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv
```

**Note**: The current contract has `_feesCollected` as private, so you cannot query it directly. The script checks the contract balance instead. If the contract only holds fees, the balance represents accumulated fees.

### Option 2: Using Forge Script (After Contract Upgrade)

**Note**: This script requires the contract to be upgraded first to expose the `feesCollected` getter. Until then, use Option 1.

```bash
# Check accumulated fees (after upgrade)
forge script script/WithdrawFees.s.sol:CheckFees \
  --rpc-url https://mainnet.base.org \
  -vvv

# Withdraw all accumulated ETH fees (after upgrade)
forge script script/WithdrawFees.s.sol:WithdrawFees \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast -vvv

If you have admin access, you can withdraw directly using `cast`:

```bash
# Withdraw all ETH fees (replace AMOUNT with actual amount in wei)
cast send 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 \
  "withdraw(uint256,address)" \
  AMOUNT \
  0x6dA173B1d50F7Bc5c686f8880C20378965408344 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY

# Withdraw ERC20 fees
cast send 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 \
  "withdraw(address,uint256,address)" \
  0xTokenAddress \
  AMOUNT \
  0x6dA173B1d50F7Bc5c686f8880C20378965408344 \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY
```

### Option 3: Upgrade Contract to Add Fee Getter (Recommended for Future)

The contract has been updated to make `feesCollected` public, allowing direct queries. However, this requires a contract upgrade:

1. **Deploy new implementation** with the updated `MarketplaceCore.sol`
2. **Upgrade the proxy** to point to the new implementation
3. **Query fees directly**: `marketplace.feesCollected(address(0))` for ETH fees

After upgrade, you can query fees directly:
```bash
# Query accumulated ETH fees
cast call 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 \
  "feesCollected(address)(uint256)" \
  0x0000000000000000000000000000000000000000 \
  --rpc-url https://mainnet.base.org
```

## Code Changes Made

1. **Made `feesCollected` mapping public** in `MarketplaceCore.sol`
   - Changed from `mapping (address => uint256) _feesCollected` to `mapping (address => uint256) public feesCollected`
   - Updated all internal references

2. **Added getter to interface** in `IMarketplaceCore.sol`
   - Added `feesCollected(address erc20) external view returns(uint256)`

3. **Created withdrawal script** `script/WithdrawFees.s.sol`
   - `CheckFees()`: View accumulated fees
   - `WithdrawFees()`: Withdraw all accumulated ETH fees
   - `WithdrawFeesPartial()`: Withdraw partial amount
   - `WithdrawERC20Fees()`: Withdraw ERC20 token fees

## Important Notes

⚠️ **Contract Upgrade Required**: The changes to make `feesCollected` public require a contract upgrade. Until then, you cannot query accumulated fees directly - you must check the contract balance or use events.

⚠️ **Admin Access Required**: Only addresses with admin privileges can call `withdraw()`. The owner/admin is `0x6dA173B1d50F7Bc5c686f8880C20378965408344`.

⚠️ **Fee Accumulation**: Fees accumulate in the contract until withdrawn. There's no automatic distribution mechanism.

## Monitoring Fees

To monitor fees going forward:

1. **Check contract balance** periodically:
   ```bash
   cast balance 0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9 --rpc-url https://mainnet.base.org
   ```

2. **Listen for `MarketplaceWithdraw` events** to track withdrawals

3. **After upgrade**: Query `feesCollected(address(0))` directly for exact accumulated amounts

## Next Steps

1. **Immediate**: Withdraw accumulated fees using Option 1 or 2 above
2. **Short-term**: Set up a regular withdrawal schedule (weekly/monthly)
3. **Long-term**: Consider upgrading the contract to enable direct fee queries
4. **Optional**: Implement an automated withdrawal mechanism (keeper bot, scheduled script, etc.)


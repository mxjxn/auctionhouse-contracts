# Auctionhouse Contracts

This is a fork of the [Manifold Gallery](https://gallery.manifold.xyz) Auctionhouse contracts, written for the [Cryptoart](https://warpcast.com/~/channel/cryptoart) channel on Farcaster. 

The main differences are:

- new listings emit an event upon creation
- the seller registry is linked to active hypersub membership (STP v2 NFT's `balanceOf` function returns time-remaining)

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

- [Capabilities Documentation](./CAPABILITIES.md) - Comprehensive guide to auctionhouse features
- [Integration Guide](./INTEGRATION_GUIDE.md) - How to integrate Creator Core contracts with the auctionhouse
- [Integration Examples](./src/examples/README.md) - Example contracts and adapters
- [Deployment Guide](./DEPLOYMENT.md) - Step-by-step deployment instructions for local and testnet

Foundry Documentation: https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

Deploy contracts using the deployment script:

**Local (Anvil)**:
```shell
# Start Anvil in a separate terminal
$ anvil

# Set environment variables
$ export PRIVATE_KEY=<your pk>

# Deploy
$ ./scripts/deploy.sh local
```

**Base Sepolia**:
```shell
# Set environment variables
$ export PRIVATE_KEY=your_private_key
$ export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org

# Deploy
$ ./scripts/deploy.sh base-sepolia
```

**Manual deployment**:
```shell
$ forge script script/DeployContracts.s.sol:DeployContracts \
    --rpc-url <your_rpc_url> \
    --broadcast
```

See the [Deployment Guide](./DEPLOYMENT.md) for detailed instructions.

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Contract Addresses

### Base Sepolia (Staging)

- Escrow: 0x30B16cbA105e5298dc2c27B9d7727b80e7754e4D
- Kaito: 0xf1966A1d1a6098c80341f38DCE1a54F8D67e8c87
- USDC: 0xd311E0ccC2E34d636c5e32853ab5Bd8aF5dB0050

### Base Mainnet(Prod)

- Escrow: 0x0e70e25d0a126Ee0a063f1Cadbe4DE8c99f3e25A
- USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553

### Monad Testnet (Staging)

- Escrow: 0x62F7B0030bb0827a2B685eDC028a021168e9eEF7

### Monad Mainnet (Prod)

- Escrow: 0xba3a334CC4abB470f66F046cE54a1DB6fB8d099E

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

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

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

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

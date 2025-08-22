## Contract Addresses

### Base Sepolia (Staging)

- Escrow: 0xdcb6256afd4e9bf395B846F9Ee78C7EE9c20Cd2e
- Kaito: 0xf1966A1d1a6098c80341f38DCE1a54F8D67e8c87

### Base Mainnet (Prod)

- Escrow: 0x29957e3b3DaBeDBE830b0De53C2C9293d0DB1bda
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553

### Monad Testnet (Staging)

- Escrow: 0x30C932752b410b2C4191d139DdC928970A982254

### Monad Testnet (Prod)

- Escrow: 0x29957e3b3DaBeDBE830b0De53C2C9293d0DB1bda

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

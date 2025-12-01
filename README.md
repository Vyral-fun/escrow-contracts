## Contract Addresses

### Base Sepolia Multi Asset(Staging) and AffiliateReward

- Escrow: 0x699257452Db6377c13F6ab275c3a7E5FAf290e90
- Kaito: 0xf1966A1d1a6098c80341f38DCE1a54F8D67e8c87
- USDC: 0xd311E0ccC2E34d636c5e32853ab5Bd8aF5dB0050

### Base Mainnet Multi Asset(Prod) and AffiliateReward

- Escrow: 0x82ca8ac7826C29C0D52B7A0FD3a9E7b2dAaA80c9
- USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553

### Monad Testnet (Staging)

- Escrow: 0xfEFB498c7DC97CE70a17214dB2Fbe97Fb67Ff627

### Monad Mainnet (Prod)

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

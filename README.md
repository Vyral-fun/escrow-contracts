## Contract Addresses

### Base Sepolia (Staging)

- Escrow: 0xdcb6256afd4e9bf395B846F9Ee78C7EE9c20Cd2e
- Kaito: 0xf1966A1d1a6098c80341f38DCE1a54F8D67e8c87

### Base Sepolia Multi Asset(Staging) and AffiliateReward

- Escrow: 0x0FCCc4f98A8bDd38BFb0E3184E4f0554B3c59369
- USDC: 0xd311E0ccC2E34d636c5e32853ab5Bd8aF5dB0050
- AVAIL: 0x38E084778b69C65d2de43B44F04E2C1391a16c61
- USDT: 0x1F54F51D1B172bF8C66C5c6dB11265FFea342cA5

### Base Mainnet (Prod)

- Escrow: 0x29957e3b3DaBeDBE830b0De53C2C9293d0DB1bda
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553

### Base Mainnet Multi Asset(Prod) and AffiliateReward

- Escrow: 0x82ca8ac7826C29C0D52B7A0FD3a9E7b2dAaA80c9
- USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553

### Base Mainnet (Staging)

- Escrow: 0xC0015ace24aa369A842fc89855e03bdEB94b965f
- Kaito: 0x98d0baa52b2D063E780DE12F615f963Fe8537553
- USDC: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

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

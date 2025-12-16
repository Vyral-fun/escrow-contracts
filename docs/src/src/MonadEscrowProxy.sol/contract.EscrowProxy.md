# EscrowProxy
[Git Source](https://github.com/Vyral-fun/escrow-contracts/blob/4890c91bba705f61bd409141a46428f143bec72f/src/MonadEscrowProxy.sol)

This contract works as a proxy that delegates calls to an implementation contract.
Only the implementation address and proxy owner are stored here.


## State Variables
### IMPLEMENTATION_SLOT

```solidity
bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```


### PROXY_ADMIN_SLOT

```solidity
bytes32 internal constant PROXY_ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
```


### __gap

```solidity
uint256[100] private __gap
```


## Functions
### constructor


```solidity
constructor(address _logicImplementation, address[] memory _admins, uint256 _currentYapRequestCount) ;
```

### upgradeTo


```solidity
function upgradeTo(address _newImplementation) external onlyProxyAdmin;
```

### _implementation


```solidity
function _implementation() internal view returns (address impl);
```

### get_implementation


```solidity
function get_implementation() external view returns (address);
```

### fallback


```solidity
fallback() external payable;
```

### _delegate


```solidity
function _delegate(address impl) internal;
```

### receive


```solidity
receive() external payable;
```

### onlyProxyAdmin


```solidity
modifier onlyProxyAdmin() ;
```

### _proxyAdmin


```solidity
function _proxyAdmin() public view returns (address admin_);
```

## Events
### Upgraded

```solidity
event Upgraded(address indexed implementation);
```

## Errors
### ImplementationRequired

```solidity
error ImplementationRequired();
```

### InitializationFailed

```solidity
error InitializationFailed();
```


# Escrow
[Git Source](https://github.com/Vyral-fun/escrow-contracts/blob/f4607b9770bff879a263b34da72431bca98521ac/src/Reward.sol)

**Inherits:**
ReentrancyGuard, Ownable


## State Variables
### kaitoTokenAddress

```solidity
address private kaitoTokenAddress
```


### s_yap_winners

```solidity
mapping(uint256 => address[]) private s_yap_winners
```


### s_yap_winners_amount

```solidity
mapping(uint256 => uint256[]) private s_yap_winners_amount
```


### s_is_admin

```solidity
mapping(address => bool) private s_is_admin
```


## Functions
### constructor


```solidity
constructor(address _kaitoAddress, address[] memory _admins) Ownable(msg.sender);
```

### rewardYapWinners

Distributes rewards to winners of a yap request


```solidity
function rewardYapWinners(uint256 yapRequestId, address[] calldata winners, uint256[] calldata winnersRewards)
    external
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yapRequestId`|`uint256`|The ID of the yap request|
|`winners`|`address[]`|Array of winner addresses|
|`winnersRewards`|`uint256[]`|Array of corresponding reward amounts for each winner|


### getWinners

Gets the winners for yap requests


```solidity
function getWinners(uint256 yapRequestId) external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of the winners of a yap requests|


### getWinnersAmounts


```solidity
function getWinnersAmounts(uint256 yapRequestId) external view returns (uint256[] memory);
```

### getBalance


```solidity
function getBalance() public view returns (uint256);
```

### withdrawBalance


```solidity
function withdrawBalance(address to) public nonReentrant onlyOwner;
```

### addAdmin


```solidity
function addAdmin(address newAdmin) public onlyOwner;
```

### isAdmin

Checks if an address is an admin


```solidity
function isAdmin(address _address) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool indicating if the address is an admin|


## Events
### RewardsDistributed

```solidity
event RewardsDistributed(uint256 indexed yapId, address[] winners, uint256 rewardPerWinner);
```

### BalanceWithdrawn

```solidity
event BalanceWithdrawn(address indexed to, address indexed caller, uint256 amount);
```

## Errors
### ValueMustBeGreaterThanZero

```solidity
error ValueMustBeGreaterThanZero();
```

### BudgetMustBeGreaterThanZero

```solidity
error BudgetMustBeGreaterThanZero();
```

### YapRequestNotFound

```solidity
error YapRequestNotFound();
```

### YapRequestNotActive

```solidity
error YapRequestNotActive();
```

### InvalidYapRequestId

```solidity
error InvalidYapRequestId();
```

### NoWinnersProvided

```solidity
error NoWinnersProvided();
```

### InvalidWinnersProvided

```solidity
error InvalidWinnersProvided();
```

### TokenTransferFailed

```solidity
error TokenTransferFailed();
```

### InvalidERC20Address

```solidity
error InvalidERC20Address();
```

### InsufficientBudget

```solidity
error InsufficientBudget();
```

### OnlyAdminsCanDistributeRewards

```solidity
error OnlyAdminsCanDistributeRewards();
```


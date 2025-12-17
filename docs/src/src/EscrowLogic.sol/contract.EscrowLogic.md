# EscrowLogic
[Git Source](https://github.com/Vyral-fun/escrow-contracts/blob/ef033620c921708ee1a686bca376289aea74c21b/src/EscrowLogic.sol)

**Inherits:**
Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable


## State Variables
### s_yapRequestCount

```solidity
uint256 private s_yapRequestCount
```


### s_allAssets

```solidity
address[] private s_allAssets
```


### NATIVE_TOKEN

```solidity
address private constant NATIVE_TOKEN = address(0)
```


### s_yapRequests

```solidity
mapping(uint256 => YapRequest) private s_yapRequests
```


### s_yapWinners

```solidity
mapping(uint256 => address[]) private s_yapWinners
```


### s_is_admin

```solidity
mapping(address => bool) private s_is_admin
```


### s_supportedAssets

```solidity
mapping(address => bool) private s_supportedAssets
```


### s_feeBalances

```solidity
mapping(address => uint256) private s_feeBalances
```


### s_minimumTotalBudget

```solidity
mapping(address => uint256) private s_minimumTotalBudget
```


### __gap

```solidity
uint256[50] private __gap
```


## Functions
### constructor


```solidity
constructor() ;
```

### initialize


```solidity
function initialize(address[] memory _admins, uint256 _currentYapRequestCount, address initialOwner)
    public
    initializer;
```

### createRequest

Creates a new yap request with specified a budget

The fee must be greater than zero

The budget must be greater than zero


```solidity
function createRequest(uint256 _budget, uint256 _fee, address _asset, string memory _jobId)
    external
    payable
    nonReentrant
    returns (uint256, uint256, uint256, address, address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_budget`|`uint256`|The budget for the yap request|
|`_fee`|`uint256`|The fee from the yap budget (1% = 1000, 0.75% = 750)|
|`_asset`|`address`||
|`_jobId`|`string`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The ID of the new yap request|
|`<none>`|`uint256`||
|`<none>`|`uint256`||
|`<none>`|`address`||
|`<none>`|`address`||


### topUpRequest

Top up an existing yap request with additional budget and fee

The total budget (additionalBudget + additionalFee) must be greater than the minimum budget for the asset


```solidity
function topUpRequest(uint256 yapRequestId, uint256 additionalBudget, uint256 additionalFee)
    external
    payable
    nonReentrant
    returns (uint256, uint256, uint256, address, address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yapRequestId`|`uint256`|The ID of the yap request to top up|
|`additionalBudget`|`uint256`|The additional budget to add to the yap request|
|`additionalFee`|`uint256`|The additional fee to add to the yap request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The updated yap request details|
|`<none>`|`uint256`||
|`<none>`|`uint256`||
|`<none>`|`address`||
|`<none>`|`address`||


### rewardYapWinners

Distributes rewards to winners of a yap request


```solidity
function rewardYapWinners(
    uint256 yapRequestId,
    address[] calldata winners,
    uint256[] calldata winnersRewards,
    bool isLastBatch
) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yapRequestId`|`uint256`|The ID of the yap request|
|`winners`|`address[]`|Array of winner addresses|
|`winnersRewards`|`uint256[]`|Array of corresponding reward amounts for each winner|
|`isLastBatch`|`bool`|Indicates if this is the last batch of winners|


### rewardAffiliateFromFees

Distributes fees rewards to affiliate of a yap campaign


```solidity
function rewardAffiliateFromFees(uint256 yapRequestId, address affiliate, uint256 reward) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yapRequestId`|`uint256`|The ID of the yap request|
|`affiliate`|`address`|affiliate that referred the campaign creator|
|`reward`|`uint256`|reward amounts for the affiliate|


### withdrawFees

Withdraw accumulated fees


```solidity
function withdrawFees(address to, uint256 amount, address asset) external onlyOwner nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to send fees to|
|`amount`|`uint256`|The amount of fees to withdraw|
|`asset`|`address`||


### resetYapRequestCount

Resets the yap request count


```solidity
function resetYapRequestCount(uint256 newYapRequstCount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newYapRequstCount`|`uint256`|The new yap request count|


### addAssetSupport

Add support for a new asset

The asset must not already be supported, and the minimum budget must be greater than zero


```solidity
function addAssetSupport(address asset, uint256 minimumBudget) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset to support|
|`minimumBudget`|`uint256`|The minimum budget required for the asset|


### removeAssetSupport

Remove support for an asset

Cannot remove core assets like NATIVE_TOKEN


```solidity
function removeAssetSupport(address asset) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset to remove support for|


### updateAssetRequirements

Update minimum requirements for an asset

The asset must be supported, and the minimum fee and budget must be greater than zero


```solidity
function updateAssetRequirements(address asset, uint256 minimumBudget) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset to update|
|`minimumBudget`|`uint256`|The new minimum budget for the asset|


### isAssetSupported

Checks if an asset is supported


```solidity
function isAssetSupported(address asset) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool indicating if the asset is supported|


### getMinimumBudget

Gets the minimum budget for a specific asset


```solidity
function getMinimumBudget(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The minimum budget required for the specified asset|


### getFeeBalance

Gets the fee balance for a specific asset


```solidity
function getFeeBalance(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current fee balance for the specified asset|


### getTotalBalance

Gets the total balance of the contract for a specific asset


```solidity
function getTotalBalance(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total balance of the contract for the specified asset|


### getYapRequest

Gets a yap request by ID


```solidity
function getYapRequest(uint256 yapRequestId) external view returns (YapRequest memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`yapRequestId`|`uint256`|The ID of the yap request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`YapRequest`|The yap request details|


### getTotalYapRequests

Gets the total number of yap requests


```solidity
function getTotalYapRequests() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total number of yap requests|


### getWinners

Gets the winners for yap requests


```solidity
function getWinners(uint256 yapRequestId) external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of the winners of a yap requests|


### getAllAssets

Gets the address of the Kaito token


```solidity
function getAllAssets() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|The address of the Kaito token|


### isAdmin

Checks if an address is an admin


```solidity
function isAdmin(address _address) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool indicating if the address is an admin|


### addAdmin

Add a new admin


```solidity
function addAdmin(address _admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address of the new admin|


### removeAdmin

Remove an admin


```solidity
function removeAdmin(address _admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address of the admin to remove|


## Events
### YapRequestCreated

```solidity
event YapRequestCreated(
    uint256 indexed yapId, address creator, string jobId, address asset, uint256 budget, uint256 fee
);
```

### Initialized

```solidity
event Initialized(address[] admins);
```

### Claimed

```solidity
event Claimed(uint256 indexed yapId, address winner, uint256 amount);
```

### AdminAdded

```solidity
event AdminAdded(address indexed admin, address indexed addedBy);
```

### AdminRemoved

```solidity
event AdminRemoved(address indexed admin, address indexed removedBy);
```

### RewardsDistributed

```solidity
event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
```

### AffiliateRewardFromFees

```solidity
event AffiliateRewardFromFees(uint256 indexed yapRequestId, address affiliate, uint256 reward);
```

### FeesWithdrawn

```solidity
event FeesWithdrawn(address indexed to, uint256 amount, address asset);
```

### CreatorRefunded

```solidity
event CreatorRefunded(uint256 indexed yapRequestId, address creator, uint256 budgetLeft);
```

### YapRequestCountReset

```solidity
event YapRequestCountReset(uint256 newYapRequestCount);
```

### MinimumFeeReset

```solidity
event MinimumFeeReset(uint256 newMinimumFee);
```

### MinimumBudgetReset

```solidity
event MinimumBudgetReset(uint256 newMinimumBudget);
```

### YapRequestTopUp

```solidity
event YapRequestTopUp(
    uint256 indexed yapId, address indexed creator, uint256 additionalBudget, uint256 additionalFee, address asset
);
```

### AssetAdded

```solidity
event AssetAdded(address indexed asset, uint256 minimumBudget);
```

### AssetRemoved

```solidity
event AssetRemoved(address indexed asset);
```

### AssetUpdated

```solidity
event AssetUpdated(address indexed asset, uint256 minimumBudget);
```

## Errors
### OnlyAdminsCanDistributeRewards

```solidity
error OnlyAdminsCanDistributeRewards();
```

### NoWinnersProvided

```solidity
error NoWinnersProvided();
```

### FeeMustBeGreaterThanZero

```solidity
error FeeMustBeGreaterThanZero();
```

### BudgetMustBeGreaterThanZero

```solidity
error BudgetMustBeGreaterThanZero();
```

### RewardMustBeGreaterThanZero

```solidity
error RewardMustBeGreaterThanZero();
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

### InvalidWinnersProvided

```solidity
error InvalidWinnersProvided();
```

### InvalidAffiliateAddress

```solidity
error InvalidAffiliateAddress();
```

### InsufficientBudget

```solidity
error InsufficientBudget();
```

### InsufficientFees

```solidity
error InsufficientFees();
```

### NotAdmin

```solidity
error NotAdmin();
```

### NotTheCreator

```solidity
error NotTheCreator();
```

### AssetNotSupported

```solidity
error AssetNotSupported();
```

### AssetAlreadySupported

```solidity
error AssetAlreadySupported();
```

### InsufficientNativeBalance

```solidity
error InsufficientNativeBalance();
```

### NoEthValueShouldBeSent

```solidity
error NoEthValueShouldBeSent();
```

### NativeTransferFailed

```solidity
error NativeTransferFailed();
```

### CannotRemoveCoreAssets

```solidity
error CannotRemoveCoreAssets();
```

## Structs
### YapRequest

```solidity
struct YapRequest {
    uint256 yapId;
    address creator;
    uint256 budget;
    uint256 fee;
    address asset;
    string jobId;
    bool isActive;
}
```


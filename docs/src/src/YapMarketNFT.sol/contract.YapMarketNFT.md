# YapMarketNFT
[Git Source](https://github.com/Vyral-fun/escrow-contracts/blob/f4607b9770bff879a263b34da72431bca98521ac/src/YapMarketNFT.sol)

**Inherits:**
ERC721Enumerable, Ownable, ReentrancyGuard


## State Variables
### s_MAX_SUPPLY

```solidity
uint256 public constant s_MAX_SUPPLY = 360
```


### s_baseURI

```solidity
string public s_baseURI
```


### s_TOKEN_OWNER

```solidity
mapping(uint256 => address) private s_TOKEN_OWNER
```


### s_KAITO

```solidity
address private s_KAITO
```


### s_PRICE

```solidity
uint256 private s_PRICE
```


## Functions
### constructor


```solidity
constructor(string memory _baseURII, address kaitoAddress, uint256 price)
    Ownable(msg.sender)
    ERC721("Yap Market Test", "YMT");
```

### mint

Mint a token to a the sender address

Reverts if the token is already minted, if the address is zero, or if the max supply is reached


```solidity
function mint(uint256 tokenId) public nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to mint|


### _baseURI

Get the base URI for the token metadata

This function is used to construct the full token URI for each token

It is overridden from the ERC721Enumerable contract


```solidity
function _baseURI() internal view override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The base URI as a string|


### setBaseURI

Set a new base URI for the token metadata

Only callable by the owner of the contract


```solidity
function setBaseURI(string memory _newBaseURI) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newBaseURI`|`string`|The new base URI to set|


### tokenURI

Get the token URI for a specific token ID


```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to get the URI for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token URI as a string|


### isHolder

Check if a wallet address is a holder of any token in this collection

This function checks if the wallet has a balance greater than zero


```solidity
function isHolder(address wallet) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`wallet`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool indicating whether the wallet is a holder|


### _tokenMinted

Get the owner of a specific token ID

This function overrides the ownerOf function from ERC721Enumerable


```solidity
function _tokenMinted(uint256 tokenId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to get the owner for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|The address of the owner of the token|


### ownerOfToken

Get the owner of a specific token ID

This function overrides the ownerOf function from ERC721Enumerable


```solidity
function ownerOfToken(uint256 tokenId) public view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The ID of the token to get the owner for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the owner of the token|


### withdraw


```solidity
function withdraw() external onlyOwner;
```

### resetPrice


```solidity
function resetPrice(uint256 price) external onlyOwner;
```

### getPrice


```solidity
function getPrice() external view returns (uint256);
```

### getKaitoAddress


```solidity
function getKaitoAddress() external view returns (address);
```

### getMaxSupply


```solidity
function getMaxSupply() external pure returns (uint256);
```

### getBalance


```solidity
function getBalance() external view returns (uint256);
```

## Events
### NFTMinted

```solidity
event NFTMinted(address indexed minter, uint256 indexed tokenId);
```

### BaseURIUpdated

```solidity
event BaseURIUpdated(string newBaseURI, address indexed updater);
```

### PriceUpdated

```solidity
event PriceUpdated(uint256 newPrice, address indexed updater);
```

### FeesWithdrawn

```solidity
event FeesWithdrawn(address indexed to, uint256 amount);
```

## Errors
### TokenAlreadyMinted

```solidity
error TokenAlreadyMinted(uint256 tokenId);
```

### InvalidTokenId

```solidity
error InvalidTokenId(uint256 tokenId);
```

### AllNFTsMinted

```solidity
error AllNFTsMinted();
```

### TokenDoesNotExist

```solidity
error TokenDoesNotExist(uint256 tokenId);
```

### IndexOutOfBounds

```solidity
error IndexOutOfBounds(uint256 index);
```

### AddressNotHolder

```solidity
error AddressNotHolder(address wallet);
```

### CannotMintToZeroAddress

```solidity
error CannotMintToZeroAddress();
```


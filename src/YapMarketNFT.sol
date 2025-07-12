// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract YapMarketNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    using Strings for uint256;

    uint256 public constant s_MAX_SUPPLY = 360;
    string public s_baseURI;
    mapping(uint256 => address) private s_TOKEN_OWNER;
    address private s_KAITO;
    uint256 private s_PRICE;

    error TokenAlreadyMinted(uint256 tokenId);
    error InvalidTokenId(uint256 tokenId);
    error AllNFTsMinted();
    error TokenDoesNotExist(uint256 tokenId);
    error IndexOutOfBounds(uint256 index);
    error AddressNotHolder(address wallet);
    error CannotMintToZeroAddress();

    event NFTMinted(address indexed minter, uint256 indexed tokenId);
    event BaseURIUpdated(string newBaseURI, address indexed updater);
    event PriceUpdated(uint256 newPrice, address indexed updater);
    event FeesWithdrawn(address indexed to, uint256 amount);

    constructor(string memory _baseURII, address kaitoAddress, uint256 price)
        Ownable(msg.sender)
        ERC721("Yap Market Test", "YMT")
    {
        s_baseURI = _baseURII;
        s_KAITO = kaitoAddress;
        s_PRICE = price;
    }

    /**
     * @notice Mint a token to a the sender address
     * @param tokenId The ID of the token to mint
     * @dev Reverts if the token is already minted, if the address is zero, or if the max supply is reached
     */
    function mint(uint256 tokenId) public nonReentrant {
        if (totalSupply() >= s_MAX_SUPPLY) {
            revert AllNFTsMinted();
        }
        if (tokenId < 1 || tokenId > s_MAX_SUPPLY) {
            revert InvalidTokenId(tokenId);
        }

        if (s_TOKEN_OWNER[tokenId] != address(0)) {
            revert TokenAlreadyMinted(tokenId);
        }

        IERC20(s_KAITO).safeTransferFrom(msg.sender, address(this), s_PRICE);

        s_TOKEN_OWNER[tokenId] = msg.sender;

        _safeMint(msg.sender, tokenId);

        emit NFTMinted(msg.sender, tokenId);
    }

    /**
     * @notice Get the base URI for the token metadata
     * @return The base URI as a string
     * @dev This function is used to construct the full token URI for each token
     * @dev It is overridden from the ERC721Enumerable contract
     */
    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }

    /**
     * @notice Set a new base URI for the token metadata
     * @param _newBaseURI The new base URI to set
     * @dev Only callable by the owner of the contract
     */
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        s_baseURI = _newBaseURI;

        emit BaseURIUpdated(_newBaseURI, msg.sender);
    }

    /**
     * @notice Get the token URI for a specific token ID
     * @param tokenId The ID of the token to get the URI for
     * @return The token URI as a string
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_tokenMinted(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }
        if (tokenId < 1 || tokenId > s_MAX_SUPPLY) {
            revert InvalidTokenId(tokenId);
        }
        return string(abi.encodePacked(s_baseURI, tokenId.toString(), ".json"));
    }

    /**
     * @notice Check if a wallet address is a holder of any token in this collection
     * @param wallet The address to check
     * @return bool indicating whether the wallet is a holder
     * @dev This function checks if the wallet has a balance greater than zero
     */
    function isHolder(address wallet) external view returns (bool) {
        return balanceOf(wallet) > 0;
    }

    /**
     * @notice Get the owner of a specific token ID
     * @param tokenId The ID of the token to get the owner for
     * @return The address of the owner of the token
     * @dev This function overrides the ownerOf function from ERC721Enumerable
     */
    function _tokenMinted(uint256 tokenId) internal view returns (bool) {
        if (s_TOKEN_OWNER[tokenId] == address(0)) {
            return false;
        }

        return true;
    }

    /**
     * @notice Get the owner of a specific token ID
     * @param tokenId The ID of the token to get the owner for
     * @return The address of the owner of the token
     * @dev This function overrides the ownerOf function from ERC721Enumerable
     */
    function ownerOfToken(uint256 tokenId) public view returns (address) {
        if (!_tokenMinted(tokenId)) {
            revert TokenDoesNotExist(tokenId);
        }
        if (tokenId < 1 || tokenId > s_MAX_SUPPLY) {
            revert InvalidTokenId(tokenId);
        }
        return s_TOKEN_OWNER[tokenId];
    }

    function withdraw() external onlyOwner {
        uint256 balance = IERC20(s_KAITO).balanceOf(address(this));
        if (balance > 0) {
            IERC20(s_KAITO).safeTransfer(msg.sender, balance);
        }

        emit FeesWithdrawn(msg.sender, balance);
    }

    function resetPrice(uint256 price) external onlyOwner {
        s_PRICE = price;

        emit PriceUpdated(price, msg.sender);
    }

    function getPrice() external view returns (uint256) {
        return s_PRICE;
    }

    function getKaitoAddress() external view returns (address) {
        return s_KAITO;
    }

    function getMaxSupply() external pure returns (uint256) {
        return s_MAX_SUPPLY;
    }

    function getBalance() external view returns (uint256) {
        return IERC20(s_KAITO).balanceOf(address(this));
    }
}

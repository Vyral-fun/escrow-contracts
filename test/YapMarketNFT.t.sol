// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/YapMarketNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Kaito", "MKT") {
        _mint(msg.sender, 1_000_000 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract YapMarketNFTTest is Test {
    YapMarketNFT nft;
    MockERC20 kaito;

    address owner = address(1);
    address user = address(2);
    address user2 = address(3);
    string baseURI = "https://yap.market/metadata/";
    uint256 price = 1 ether;

    function setUp() public {
        vm.startPrank(owner);
        kaito = new MockERC20();
        nft = new YapMarketNFT(baseURI, address(kaito), price);
        vm.stopPrank();

        vm.startPrank(owner);
        kaito.transfer(user, 300 ether);
        kaito.transfer(user2, 300 ether);
        vm.stopPrank();
    }

    function testInitialState() public {
        assertEq(nft.owner(), owner);
        assertEq(nft.getPrice(), price);
        assertEq(nft.getKaitoAddress(), address(kaito));
        assertEq(nft.getMaxSupply(), 360);
        assertEq(nft.totalSupply(), 0);
    }

    function testMintNFT() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);

        assertEq(nft.ownerOf(1), user);
        assertEq(nft.balanceOf(user), 1);
        assertEq(nft.totalSupply(), 1);

        string memory uri = nft.tokenURI(1);
        assertEq(uri, string.concat(baseURI, "1.json"));
        vm.stopPrank();
    }

    function testMintMultipleNFTs() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price * 3);

        nft.mint(1);
        nft.mint(2);
        nft.mint(3);

        assertEq(nft.balanceOf(user), 3);
        assertEq(nft.totalSupply(), 3);
        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), user);
        assertEq(nft.ownerOf(3), user);
        vm.stopPrank();
    }

    function testMintAlreadyMinted() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price * 2);
        nft.mint(1);

        vm.expectRevert(abi.encodeWithSignature("TokenAlreadyMinted(uint256)", 1));
        nft.mint(1);
        vm.stopPrank();
    }

    function testMintInvalidTokenIdZero() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);

        vm.expectRevert(abi.encodeWithSignature("InvalidTokenId(uint256)", 0));
        nft.mint(0);
        vm.stopPrank();
    }

    function testMintInvalidTokenIdTooHigh() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);

        vm.expectRevert(abi.encodeWithSignature("InvalidTokenId(uint256)", 361));
        nft.mint(361);
        vm.stopPrank();
    }

    function testMintInsufficientBalance() public {
        vm.startPrank(user2);
        // Don't approve enough tokens
        kaito.approve(address(nft), price - 1);

        vm.expectRevert();
        nft.mint(1);
        vm.stopPrank();
    }

    function testMintInsufficientAllowance() public {
        vm.startPrank(user);
        // Don't approve any tokens
        vm.expectRevert();
        nft.mint(1);
        vm.stopPrank();
    }

    function testAllNFTsMinted() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price * 200);

        for (uint256 i = 1; i <= 200; i++) {
            nft.mint(i);
        }
        vm.stopPrank();

        vm.prank(owner);
        kaito.transfer(user2, price * 60);

        vm.startPrank(user2);
        kaito.approve(address(nft), price * 160);

        for (uint256 i = 201; i <= 360; i++) {
            nft.mint(i);
        }

        vm.expectRevert(YapMarketNFT.AllNFTsMinted.selector);
        nft.mint(361);
        vm.stopPrank();
    }

    function testWithdrawFees() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);
        vm.stopPrank();

        uint256 ownerBalanceBefore = kaito.balanceOf(owner);
        uint256 contractBalance = nft.getBalance();

        vm.prank(owner);
        nft.withdraw();

        uint256 ownerBalanceAfter = kaito.balanceOf(owner);
        assertEq(ownerBalanceAfter - ownerBalanceBefore, contractBalance);
        assertEq(nft.getBalance(), 0);
    }

    function testWithdrawFeesOnlyOwner() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);

        vm.expectRevert();
        nft.withdraw();
        vm.stopPrank();
    }

    function testResetPrice() public {
        vm.prank(owner);
        nft.resetPrice(2 ether);

        assertEq(nft.getPrice(), 2 ether);
    }

    function testResetPriceOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        nft.resetPrice(2 ether);
    }

    function testSetBaseURI() public {
        vm.prank(owner);
        nft.setBaseURI("https://newuri.com/");

        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);
        string memory uri = nft.tokenURI(1);
        assertEq(uri, "https://newuri.com/1.json");
        vm.stopPrank();
    }

    function testSetBaseURIOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        nft.setBaseURI("https://newuri.com/");
    }

    function testIsHolder() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);

        bool holder = nft.isHolder(user);
        assertTrue(holder);

        bool nonHolder = nft.isHolder(user2);
        assertFalse(nonHolder);
        vm.stopPrank();
    }

    function testOwnerOfToken() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);
        vm.stopPrank();

        address tokenOwner = nft.ownerOfToken(1);
        assertEq(tokenOwner, user);
    }

    function testOwnerOfTokenNotMinted() public {
        vm.expectRevert();
        nft.ownerOfToken(1);
    }

    function testGetBalance() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);
        vm.stopPrank();

        uint256 balance = nft.getBalance();
        assertEq(balance, price);
    }

    function testTransferAfterMint() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);

        nft.transferFrom(user, user2, 1);

        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user), 0);
        assertEq(nft.balanceOf(user2), 1);
        vm.stopPrank();
    }

    function testTokenURIForNonExistentToken() public {
        vm.expectRevert();
        nft.tokenURI(1);
    }

    function testPriceUpdate() public {
        uint256 newPrice = 2.5 ether;

        vm.prank(owner);
        nft.resetPrice(newPrice);

        vm.startPrank(user);
        kaito.approve(address(nft), newPrice);
        nft.mint(1);

        assertEq(nft.getBalance(), newPrice);
        vm.stopPrank();
    }

    function testMultipleUsersCanMint() public {
        vm.startPrank(user);
        kaito.approve(address(nft), price);
        nft.mint(1);
        vm.stopPrank();

        vm.startPrank(user2);
        kaito.approve(address(nft), price);
        nft.mint(2);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user);
        assertEq(nft.ownerOf(2), user2);
        assertEq(nft.totalSupply(), 2);
        assertEq(nft.getBalance(), price * 2);
    }

    function testSupportsInterface() public {
        // Test ERC721 interface
        assertTrue(nft.supportsInterface(0x80ac58cd));
        // Test ERC165 interface
        assertTrue(nft.supportsInterface(0x01ffc9a7));
    }
}

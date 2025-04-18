// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EscrowLogic} from "../src/EscrowLogic.sol";
import {EscrowProxy} from "../src/EscrowProxy.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import "forge-std/console.sol";

contract EscrowProxyTest is Test {
    EscrowLogic public escrowLogic;
    EscrowProxy public escrowProxy;
    EscrowLogic public escrowProxyAsLogic;
    MockERC20 public kaitoToken;

    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public winner1;
    address public winner2;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REQUEST_BUDGET = 10 ether;
    uint256 public constant REQUEST_FEE = 1 ether;
    uint256 public constant REWARD_AMOUNT = 2 ether;
    uint256 public constant BUFFER_TIME = 1; // 1 day buffer time

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        winner1 = makeAddr("winner1");
        winner2 = makeAddr("winner2");

        kaitoToken = new MockERC20("Kaito Token", "KTO", 18);
        kaitoToken.mint(user1, INITIAL_BALANCE);
        kaitoToken.mint(user2, INITIAL_BALANCE);

        escrowLogic = new EscrowLogic();

        address[] memory admins = new address[](1);
        admins[0] = admin;

        escrowProxy = new EscrowProxy(address(escrowLogic), address(kaitoToken), admins, BUFFER_TIME, 0);

        escrowProxyAsLogic = EscrowLogic(address(escrowProxy));

        address impl = escrowProxy.get_implementation();
        address proxyOwner = escrowProxy.owner();

        console.log(address(escrowProxy));
        console.log(address(escrowProxyAsLogic));
        console.log(address(escrowLogic));
        console.log(impl);
        console.log(proxyOwner);
    }

    function testInitialization() public {
        address implementationAddress = escrowProxy.get_implementation();
        assertEq(implementationAddress, address(escrowLogic));

        address tokenAddress = escrowProxyAsLogic.getKaitoAddress();
        assertEq(tokenAddress, address(kaitoToken));

        bool isAdmin = escrowProxyAsLogic.isAdmin(admin);
        assertTrue(isAdmin);

        bool isOwnerAdmin = escrowProxyAsLogic.isAdmin(address(this));
        assertTrue(isOwnerAdmin);

        uint256 bufferTime = escrowProxyAsLogic.getBufferTime();
        assertEq(bufferTime, BUFFER_TIME * 1 days);
    }

    function testCreateRequest() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), REQUEST_BUDGET + REQUEST_FEE);

        uint256 yapId = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, REQUEST_FEE);
        vm.stopPrank();

        assertEq(yapId, 1);
        assertEq(escrowProxyAsLogic.getTotalYapRequests(), 1);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);
        assertEq(yapRequest.yapId, 1);
        assertEq(yapRequest.creator, user1);
        assertEq(yapRequest.budget, REQUEST_BUDGET);
        assertTrue(yapRequest.isActive);

        assertEq(escrowProxyAsLogic.getFeeBalance(), REQUEST_FEE);

        assertEq(kaitoToken.balanceOf(address(escrowProxy)), REQUEST_BUDGET + REQUEST_FEE);
    }

    function testApproveWinner() public {
        testCreateRequest();

        vm.startPrank(admin);
        escrowProxyAsLogic.approveYapWinner(1, winner1, REWARD_AMOUNT);
        vm.stopPrank();

        address[] memory winners = escrowProxyAsLogic.getWinners(1);
        assertEq(winners.length, 1);
        assertEq(winners[0], winner1);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);
        assertEq(yapRequest.budget, REQUEST_BUDGET - REWARD_AMOUNT);
        assertTrue(yapRequest.isActive);
    }

    function testClaimReward() public {
        testApproveWinner();

        vm.warp(block.timestamp + BUFFER_TIME * 1 days + 1);

        uint256 balanceBefore = kaitoToken.balanceOf(winner1);

        vm.startPrank(winner1);
        escrowProxyAsLogic.claimYapWinners(1);
        vm.stopPrank();

        uint256 balanceAfter = kaitoToken.balanceOf(winner1);
        assertEq(balanceAfter - balanceBefore, REWARD_AMOUNT);
    }

    function testWithdrawFees() public {
        testCreateRequest();

        address feeRecipient = makeAddr("feeRecipient");

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance();
        escrowProxyAsLogic.withdrawFees(feeRecipient, feeBalance);

        assertEq(kaitoToken.balanceOf(feeRecipient), feeBalance);
        assertEq(escrowProxyAsLogic.getFeeBalance(), 0);
    }

    function testUpgradeImplementation() public {
        EscrowLogic newLogic = new EscrowLogic();

        escrowProxy.upgradeTo(address(newLogic));

        assertEq(escrowProxy.get_implementation(), address(newLogic));

        vm.startPrank(user2);
        kaitoToken.approve(address(escrowProxy), REQUEST_BUDGET + REQUEST_FEE);
        uint256 yapId = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, REQUEST_FEE);
        vm.stopPrank();

        assertEq(yapId, 1);

        vm.startPrank(user2);
        kaitoToken.approve(address(escrowProxy), REQUEST_BUDGET + REQUEST_FEE);
        uint256 newyapId = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, REQUEST_FEE);
        vm.stopPrank();

        assertEq(newyapId, 2);
    }

    function testAddRemoveAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        assertFalse(escrowProxyAsLogic.isAdmin(newAdmin));

        escrowProxyAsLogic.addAdmin(newAdmin);

        assertTrue(escrowProxyAsLogic.isAdmin(newAdmin));

        escrowProxyAsLogic.removeAdmin(newAdmin);

        assertFalse(escrowProxyAsLogic.isAdmin(newAdmin));
    }

    function testRevert_CannotCreateRequestWithZeroBudget() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), REQUEST_FEE);
        vm.expectRevert(EscrowLogic.BudgetMustBeGreaterThanZero.selector);
        escrowProxyAsLogic.createRequest(0, REQUEST_FEE);
        vm.stopPrank();
    }

    function testRevert_CannotCreateRequestWithZeroFee() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), REQUEST_BUDGET);
        vm.expectRevert(EscrowLogic.FeeMustBeGreaterThanZero.selector);
        escrowProxyAsLogic.createRequest(REQUEST_BUDGET, 0);
        vm.stopPrank();
    }

    function testRevert_NonAdminCannotApproveWinner() public {
        testCreateRequest();

        vm.startPrank(user2);
        vm.expectRevert(EscrowLogic.NotAdmin.selector);
        escrowProxyAsLogic.approveYapWinner(1, winner1, REWARD_AMOUNT);
        vm.stopPrank();
    }

    function testRevert_CannotApproveWithInsufficientBudget() public {
        testCreateRequest();

        vm.startPrank(admin);
        vm.expectRevert(EscrowLogic.InsufficientBudget.selector);
        escrowProxyAsLogic.approveYapWinner(1, winner1, REQUEST_BUDGET + 1);
        vm.stopPrank();
    }

    function testRevert_CannotClaimBeforeBufferTime() public {
        testApproveWinner();

        vm.startPrank(winner1);
        vm.expectRevert(EscrowLogic.CannotClaimYet.selector);
        escrowProxyAsLogic.claimYapWinners(1);
        vm.stopPrank();
    }

    function testRevert_InvalidWinnerClaim() public {
        testApproveWinner();

        vm.warp(block.timestamp + BUFFER_TIME * 1 days + 1);

        vm.startPrank(user2);
        vm.expectRevert(EscrowLogic.NotAValidApproval.selector);
        escrowProxyAsLogic.claimYapWinners(1);
        vm.stopPrank();
    }

    function testRevert_NonOwnerCannotWithdrawFees() public {
        testCreateRequest();

        vm.startPrank(user1);
        vm.expectRevert();
        escrowProxyAsLogic.withdrawFees(user1, REQUEST_FEE);
        vm.stopPrank();
    }

    function testRevert_NonOwnerCannotUpgradeImplementation() public {
        EscrowLogic newLogic = new EscrowLogic();

        vm.startPrank(user1);
        vm.expectRevert(EscrowLogic.NotOwner.selector);
        escrowProxy.upgradeTo(address(newLogic));
        vm.stopPrank();
    }

    function testMultipleWinnerFlow() public {
        testCreateRequest();

        vm.startPrank(admin);
        escrowProxyAsLogic.approveYapWinner(1, winner1, REWARD_AMOUNT);
        escrowProxyAsLogic.approveYapWinner(1, winner2, REWARD_AMOUNT);
        vm.stopPrank();

        address[] memory winners = escrowProxyAsLogic.getWinners(1);
        assertEq(winners.length, 2);
        assertEq(winners[0], winner1);
        assertEq(winners[1], winner2);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);
        assertEq(yapRequest.budget, REQUEST_BUDGET - (REWARD_AMOUNT * 2));
        assertTrue(yapRequest.isActive);

        vm.warp(block.timestamp + BUFFER_TIME * 1 days + 1);

        uint256 winner1BalanceBefore = kaitoToken.balanceOf(winner1);
        uint256 winner2BalanceBefore = kaitoToken.balanceOf(winner2);

        vm.startPrank(winner1);
        escrowProxyAsLogic.claimYapWinners(1);
        vm.stopPrank();

        vm.startPrank(winner2);
        escrowProxyAsLogic.claimYapWinners(1);
        vm.stopPrank();

        uint256 winner1BalanceAfter = kaitoToken.balanceOf(winner1);
        uint256 winner2BalanceAfter = kaitoToken.balanceOf(winner2);

        assertEq(winner1BalanceAfter - winner1BalanceBefore, REWARD_AMOUNT);
        assertEq(winner2BalanceAfter - winner2BalanceBefore, REWARD_AMOUNT);
    }
}

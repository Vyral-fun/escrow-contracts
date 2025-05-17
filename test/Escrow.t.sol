// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EscrowLogic} from "../src/EscrowLogic.sol";
import {EscrowProxy} from "../src/EscrowProxy.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Router02} from "./mocks/MockUniswapV2Router.sol";
import {MockUniswapV2Factory} from "./mocks/MockUniswapV2Factory.sol";
import "forge-std/console.sol";

contract EscrowProxyTest is Test {
    EscrowLogic public escrowLogic;
    EscrowProxy public escrowProxy;
    EscrowLogic public escrowProxyAsLogic;
    MockERC20 public kaitoToken;
    MockERC20 public usdcToken;
    MockERC20 public usdtToken;
    MockUniswapV2Factory public mockFactory;
    MockUniswapV2Router02 public mockRouter;

    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public winner1;
    address public winner2;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REQUEST_BUDGET = 9 ether;
    uint256 public constant TOTAL_REQUEST_BUDGET = 10 ether;
    uint256 public constant FEE = 1 ether;
    uint256 public constant REWARD_AMOUNT = 2 ether;

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget, uint256 fee);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
    event Upgraded(address indexed implementation);

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

        escrowProxy = new EscrowProxy(address(escrowLogic), address(kaitoToken), admins, 0);

        address impl = escrowProxy.get_implementation();
        escrowProxyAsLogic = EscrowLogic(address(escrowProxy));

        console.log(address(escrowProxy));
        console.log(address(escrowProxyAsLogic));
        console.log(address(escrowLogic));
        console.log(impl);
    }

    function testCreateRequestWithKaito() public {
        vm.startPrank(user1);

        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);

        vm.expectEmit(true, true, false, true);
        emit YapRequestCreated(1, user1, 9 ether, 1 ether);

        (uint256 yapId, uint256 exactBudget,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);

        vm.stopPrank();

        assertEq(yapId, 1);
        assertEq(exactBudget, 9 ether);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);

        assertEq(yapRequest.creator, user1);
        assertEq(yapRequest.budget, 9 ether);
        assertTrue(yapRequest.isActive);

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance();
        assertEq(feeBalance, 1 ether);
    }

    function testRewardYapWinners() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = winner1;
        winners[1] = winner2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = REWARD_AMOUNT;
        rewards[1] = REWARD_AMOUNT;

        uint256 winner1InitialBalance = kaitoToken.balanceOf(winner1);
        uint256 winner2InitialBalance = kaitoToken.balanceOf(winner2);

        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true);
        emit RewardsDistributed(yapId, winners, REWARD_AMOUNT * 2);

        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards);
        vm.stopPrank();

        assertEq(kaitoToken.balanceOf(winner1), winner1InitialBalance + REWARD_AMOUNT);
        assertEq(kaitoToken.balanceOf(winner2), winner2InitialBalance + REWARD_AMOUNT);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 9 ether - (REWARD_AMOUNT * 2));
        assertTrue(yapRequest.isActive);

        address[] memory yap1Winners = escrowProxyAsLogic.getWinners(yapId);
        assertEq(yap1Winners.length, 2);
        assertEq(yap1Winners[0], winner1);
        assertEq(yap1Winners[1], winner2);
    }

    function testWithdrawFees() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance();
        assertEq(feeBalance, 1 ether);

        address feeReceiver = makeAddr("feeReceiver");
        uint256 initialBalance = kaitoToken.balanceOf(feeReceiver);

        escrowProxyAsLogic.withdrawFees(feeReceiver, feeBalance);

        uint256 newFeeBalance = escrowProxyAsLogic.getFeeBalance();
        assertEq(newFeeBalance, 0);
        assertEq(kaitoToken.balanceOf(feeReceiver), initialBalance + feeBalance);
    }

    function testRewardYapWinnersNonAdminReverts() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = winner1;
        winners[1] = winner2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = REWARD_AMOUNT;
        rewards[1] = REWARD_AMOUNT;

        vm.startPrank(user2);
        vm.expectRevert(EscrowLogic.OnlyAdminsCanDistributeRewards.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards);
        vm.stopPrank();
    }

    function testUpgradeImpl() public {
        EscrowLogic newImpl = new EscrowLogic();

        address currentImpl = escrowProxy.get_implementation();
        assertEq(currentImpl, address(escrowLogic));

        vm.expectEmit(true, false, false, false);
        emit Upgraded(address(newImpl));

        escrowProxy.upgradeTo(address(newImpl));

        address updatedImpl = escrowProxy.get_implementation();
        assertEq(updatedImpl, address(newImpl));
    }

    function testUpgradeImplNonOwner() public {
        EscrowLogic newImpl = new EscrowLogic();

        vm.startPrank(user1);
        vm.expectRevert(EscrowProxy.NotOwner.selector);
        escrowProxy.upgradeTo(address(newImpl));
        vm.stopPrank();

        address currentImpl = escrowProxy.get_implementation();
        assertEq(currentImpl, address(escrowLogic));
    }

    function testAddAndRemoveAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        assertFalse(escrowProxyAsLogic.isAdmin(newAdmin));
        assertTrue(escrowProxyAsLogic.isAdmin(admin));

        escrowProxyAsLogic.addAdmin(newAdmin);
        assertTrue(escrowProxyAsLogic.isAdmin(newAdmin));

        escrowProxyAsLogic.removeAdmin(admin);
        assertFalse(escrowProxyAsLogic.isAdmin(admin));
    }

    function testResetKaitoAddress() public {
        MockERC20 newKaitoToken = new MockERC20("New Kaito Token", "NKTO", 18);

        address currentKaitoAddr = escrowProxyAsLogic.getKaitoAddress();
        assertEq(currentKaitoAddr, address(kaitoToken));

        escrowProxyAsLogic.resetKaitoAddress(address(newKaitoToken));

        address newKaitoAddr = escrowProxyAsLogic.getKaitoAddress();
        assertEq(newKaitoAddr, address(newKaitoToken));
    }

    function testGetTotalYapRequests() public {
        assertEq(escrowProxyAsLogic.getTotalYapRequests(), 0);

        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        assertEq(escrowProxyAsLogic.getTotalYapRequests(), 1);

        vm.startPrank(user2);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        assertEq(escrowProxyAsLogic.getTotalYapRequests(), 2);
    }

    function testCloseYapRequestWithFullRewards() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId, uint256 exactBudget,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](1);
        winners[0] = winner1;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = exactBudget;

        vm.startPrank(admin);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards);
        vm.stopPrank();

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);
    }

    function testRewardYapWinnersMismatchedArraysReverts() public {
        // Create a yap request
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = winner1;
        winners[1] = winner2;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = REWARD_AMOUNT;

        vm.startPrank(admin);
        vm.expectRevert(EscrowLogic.InvalidWinnersProvided.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards);
        vm.stopPrank();
    }

    function testRewardYapWinnersExceedingBudgetReverts() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId, uint256 exactBudget,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](1);
        winners[0] = winner1;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = exactBudget + 1 ether;

        vm.startPrank(admin);
        vm.expectRevert(EscrowLogic.InsufficientBudget.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards);
        vm.stopPrank();
    }

    function testWithdrawFeesExceedingBalanceReverts() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance();

        vm.expectRevert(EscrowLogic.InsufficientBudget.selector);
        escrowProxyAsLogic.withdrawFees(address(this), feeBalance + 1 ether);
    }
}

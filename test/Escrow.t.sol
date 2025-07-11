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
    uint256 public constant REQUEST_BUDGET = 9 ether;
    uint256 public constant TOTAL_REQUEST_BUDGET = 10 ether;
    uint256 public constant FEE = 1 ether;
    uint256 public constant REWARD_AMOUNT = 2 ether;

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget, uint256 fee);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
    event CreatorRefunded(uint256 indexed yapRequestId, address creator, uint256 budgetLeft);
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
        address logicOwner = escrowLogic.owner();

        address[] memory admins = new address[](2);
        admins[0] = admin;
        admins[1] = owner;

        escrowProxy = new EscrowProxy(address(escrowLogic), address(kaitoToken), admins, 0);

        address impl = escrowProxy.get_implementation();
        escrowProxyAsLogic = EscrowLogic(address(escrowProxy));

        console.log("Proxy address:", address(escrowProxy));
        console.log("Proxy as Logic address:", address(escrowProxyAsLogic));
        console.log("Logic implementation:", address(escrowLogic));
        console.log("Implementation from proxy:", impl);
        console.log("Owner", owner);
        console.log("Ownwr", logicOwner);
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

    function testRewardYapWinnersWithRefund() public {
        vm.startPrank(user1);
        uint256 user1InitialBalance = kaitoToken.balanceOf(user1);
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

        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();

        assertEq(kaitoToken.balanceOf(winner1), winner1InitialBalance + REWARD_AMOUNT);
        assertEq(kaitoToken.balanceOf(winner2), winner2InitialBalance + REWARD_AMOUNT);

        uint256 expectedRefund = REQUEST_BUDGET - (REWARD_AMOUNT * 2);
        uint256 expectedFinalBalance = user1InitialBalance - TOTAL_REQUEST_BUDGET + expectedRefund;
        assertEq(kaitoToken.balanceOf(user1), expectedFinalBalance);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);

        address[] memory yap1Winners = escrowProxyAsLogic.getWinners(yapId);
        assertEq(yap1Winners.length, 2);
        assertEq(yap1Winners[0], winner1);
        assertEq(yap1Winners[1], winner2);
    }

    function testRewardYapWinnersMultipleBatches() public {
        vm.startPrank(user1);
        uint256 user1InitialBalance = kaitoToken.balanceOf(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners1 = new address[](1);
        winners1[0] = winner1;
        uint256[] memory rewards1 = new uint256[](1);
        rewards1[0] = REWARD_AMOUNT;

        address[] memory winners2 = new address[](1);
        winners2[0] = winner2;
        uint256[] memory rewards2 = new uint256[](1);
        rewards2[0] = REWARD_AMOUNT;

        uint256 winner1InitialBalance = kaitoToken.balanceOf(winner1);
        uint256 winner2InitialBalance = kaitoToken.balanceOf(winner2);

        vm.startPrank(admin);

        escrowProxyAsLogic.rewardYapWinners(yapId, winners1, rewards1, false);

        EscrowLogic.YapRequest memory yapRequestAfterFirst = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequestAfterFirst.budget, REQUEST_BUDGET - REWARD_AMOUNT);
        assertTrue(yapRequestAfterFirst.isActive);

        escrowProxyAsLogic.rewardYapWinners(yapId, winners2, rewards2, true);
        vm.stopPrank();

        assertEq(kaitoToken.balanceOf(winner1), winner1InitialBalance + REWARD_AMOUNT);
        assertEq(kaitoToken.balanceOf(winner2), winner2InitialBalance + REWARD_AMOUNT);

        uint256 expectedRefund = REQUEST_BUDGET - (REWARD_AMOUNT * 2);
        uint256 expectedFinalBalance = user1InitialBalance - TOTAL_REQUEST_BUDGET + expectedRefund;
        assertEq(kaitoToken.balanceOf(user1), expectedFinalBalance);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);

        address[] memory allWinners = escrowProxyAsLogic.getWinners(yapId);
        assertEq(allWinners.length, 2);
        assertEq(allWinners[0], winner1);
        assertEq(allWinners[1], winner2);
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
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();
    }

    function testUpgradeImpl() public {
        EscrowLogic newImpl = new EscrowLogic();

        address currentImpl = escrowProxy.get_implementation();
        assertEq(currentImpl, address(escrowLogic));

        vm.prank(owner);
        escrowProxy.upgradeTo(address(newImpl));

        address updatedImpl = escrowProxy.get_implementation();
        assertEq(updatedImpl, address(newImpl));
    }

    function testUpgradeImplNonOwnerReverts() public {
        EscrowLogic newImpl = new EscrowLogic();

        vm.startPrank(user1);
        vm.expectRevert();
        escrowProxy.upgradeTo(address(newImpl));
        vm.stopPrank();

        address currentImpl = escrowProxy.get_implementation();
        assertEq(currentImpl, address(escrowLogic));
    }

    function testAddAndRemoveAdmin() public {
        address newAdmin = makeAddr("newAdmin");

        assertFalse(escrowProxyAsLogic.isAdmin(newAdmin));
        assertTrue(escrowProxyAsLogic.isAdmin(admin));
        assertEq(escrowProxyAsLogic.owner(), owner);

        vm.startPrank(owner);
        escrowProxyAsLogic.addAdmin(newAdmin);
        assertTrue(escrowProxyAsLogic.isAdmin(newAdmin));

        vm.startPrank(owner);
        escrowProxyAsLogic.removeAdmin(admin);
        assertFalse(escrowProxyAsLogic.isAdmin(admin));
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
        uint256 user1InitialBalance = kaitoToken.balanceOf(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId, uint256 exactBudget,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](1);
        winners[0] = winner1;

        uint256[] memory rewards = new uint256[](1);
        rewards[0] = exactBudget;

        vm.startPrank(admin);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();

        uint256 expectedFinalBalance = user1InitialBalance - TOTAL_REQUEST_BUDGET;
        assertEq(kaitoToken.balanceOf(user1), expectedFinalBalance);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);
    }

    function testRewardYapWinnersMismatchedArraysReverts() public {
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
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
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
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
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

    function testRewardYapWinnersInactiveRequestReverts() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](1);
        winners[0] = winner1;
        uint256[] memory rewards = new uint256[](1);
        rewards[0] = 1 ether;

        vm.startPrank(admin);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);

        kaitoToken.mint(admin, 10 ether);
        kaitoToken.approve(address(escrowProxy), 10 ether);

        vm.expectRevert(EscrowLogic.YapRequestNotActive.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();
    }

    function testRewardYapWinnersEmptyArraysReverts() public {
        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,) = escrowProxyAsLogic.createRequest(REQUEST_BUDGET, FEE);
        vm.stopPrank();

        address[] memory winners = new address[](0);
        uint256[] memory rewards = new uint256[](0);

        vm.startPrank(admin);
        vm.expectRevert(EscrowLogic.NoWinnersProvided.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();
    }

    function testGetYapRequestInvalidIdReverts() public {
        vm.expectRevert(EscrowLogic.YapRequestNotFound.selector);
        escrowProxyAsLogic.getYapRequest(999);
    }

    function testTopUpRequest() public {
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

        vm.startPrank(user1);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (, uint256 newTotalBudget,,) = escrowProxyAsLogic.topUpRequest(yapId, REQUEST_BUDGET, FEE);

        vm.stopPrank();

        assertEq(yapId, 1);
        assertEq(newTotalBudget, 18 ether);
    }

    function testTopUpRequestNonCreatorReverts() public {
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

        vm.startPrank(user2);
        kaitoToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        vm.expectRevert(EscrowLogic.NotTheCreator.selector);
        escrowProxyAsLogic.topUpRequest(yapId, REQUEST_BUDGET, FEE);

        vm.stopPrank();
    }
}

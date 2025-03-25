// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Escrow} from "../src/Escrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    MockERC20 public kaitoToken;

    address public owner;
    address public user1;
    address public user2;
    address public winner1;
    address public winner2;

    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant REQUEST_AMOUNT = 10 ether;
    uint256 public constant REWARD_AMOUNT = 1 ether;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        winner1 = makeAddr("winner1");
        winner2 = makeAddr("winner2");

        kaitoToken = new MockERC20("Kaito Token", "KTO", 18);

        escrow = new Escrow(address(kaitoToken));

        kaitoToken.mint(user1, INITIAL_BALANCE);
        kaitoToken.mint(user2, INITIAL_BALANCE);
    }

    function test_CreateERC20Request() public {
        uint256 budget = REQUEST_AMOUNT;

        vm.startPrank(user1);
        kaitoToken.approve(address(escrow), REQUEST_AMOUNT);
        escrow.createRequest(budget);
        vm.stopPrank();

        assertEq(escrow.getTotalYapRequests(), 1);

        vm.startPrank(user1);
        Escrow.YapRequest memory yapRequest = escrow.getYapRequest(1);
        vm.stopPrank();

        assertEq(yapRequest.yapId, 1);
        assertEq(yapRequest.creator, user1);
        assertEq(yapRequest.budget, REQUEST_AMOUNT);
        assertEq(yapRequest.isActive, true);
    }

    function test_RewardYapWinnersERC20() public {
        test_CreateERC20Request();

        uint256 winner1BalanceBefore = kaitoToken.balanceOf(winner1);
        uint256 winner2BalanceBefore = kaitoToken.balanceOf(winner2);

        address[] memory winners = new address[](2);
        uint256[] memory winnersRewards = new uint256[](2);
        winners[0] = winner1;
        winners[1] = winner2;
        winnersRewards[0] = REWARD_AMOUNT;
        winnersRewards[1] = REWARD_AMOUNT;

        vm.startPrank(user1);
        escrow.rewardYapWinners(1, winners, winnersRewards);
        vm.stopPrank();

        uint256 winner1BalanceAfter = kaitoToken.balanceOf(winner1);
        uint256 winner2BalanceAfter = kaitoToken.balanceOf(winner2);

        assertEq(winner1BalanceAfter - winner1BalanceBefore, REWARD_AMOUNT);
        assertEq(winner2BalanceAfter - winner2BalanceBefore, REWARD_AMOUNT);

        vm.startPrank(user1);
        Escrow.YapRequest memory yapRequest = escrow.getYapRequest(1);
        vm.stopPrank();
        assertEq(yapRequest.isActive, false);
    }

    function test_RevertWhen_ZeroBudget() public {
        uint256 budget = 0;

        vm.startPrank(user1);
        vm.expectRevert(Escrow.BudgetMustBeGreaterThanZero.selector);
        escrow.createRequest(budget);
        vm.stopPrank();
    }

    function test_RevertWhen_OnlyCreatorCanReward() public {
        test_CreateERC20Request();

        address[] memory winners = new address[](2);
        uint256[] memory winnersRewards = new uint256[](2);
        winners[0] = winner1;
        winners[1] = winner2;
        winnersRewards[0] = REWARD_AMOUNT;
        winnersRewards[1] = REWARD_AMOUNT;

        vm.startPrank(user2);
        vm.expectRevert(Escrow.OnlyCreatorCanDistributeRewards.selector);
        escrow.rewardYapWinners(1, winners, winnersRewards);
        vm.stopPrank();
    }

    function test_RevertWhen_RewardInactiveRequest() public {
        test_RewardYapWinnersERC20();

        address[] memory winners = new address[](2);
        uint256[] memory winnersRewards = new uint256[](2);
        winners[0] = winner1;
        winners[1] = winner2;
        winnersRewards[0] = REWARD_AMOUNT;
        winnersRewards[1] = REWARD_AMOUNT;

        vm.startPrank(user1);
        vm.expectRevert(Escrow.YapRequestNotActive.selector);
        escrow.rewardYapWinners(1, winners, winnersRewards);
        vm.stopPrank();
    }

    function test_RevertWhen_EmptyWinners() public {
        test_CreateERC20Request();

        address[] memory winners = new address[](0);
        uint256[] memory winnersRewards = new uint256[](0);

        vm.startPrank(user1);
        vm.expectRevert(Escrow.NoWinnersProvided.selector);
        escrow.rewardYapWinners(1, winners, winnersRewards);
        vm.stopPrank();
    }
}

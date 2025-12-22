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
    MockERC20 public testToken;

    address public owner;
    address public admin;
    address public user1;
    address public user2;
    address public winner1;
    address public winner2;

    address public constant NATIVE_TOKEN = address(0);

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REQUEST_BUDGET = 9 ether;
    uint256 public constant TOTAL_REQUEST_BUDGET = 10 ether;
    uint256 public constant FEE = 1 ether;
    uint256 public constant REWARD_AMOUNT = 2 ether;
    uint256 public constant MINIMUM_TOTAL_BUDGET = 100000;

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, address asset, uint256 budget, uint256 fee);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
    event CreatorRefunded(uint256 indexed yapRequestId, address creator, uint256 budgetLeft);
    event Upgraded(address indexed implementation);
    event AssetAdded(address indexed asset, uint256 minimumBudget);

    function setUp() public {
        owner = address(this);
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        winner1 = makeAddr("winner1");
        winner2 = makeAddr("winner2");

        // Give users ETH for native token tests
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);

        testToken = new MockERC20("Test Token", "TST", 18);
        testToken.mint(user1, INITIAL_BALANCE);
        testToken.mint(user2, INITIAL_BALANCE);

        escrowLogic = new EscrowLogic();

        address[] memory admins = new address[](2);
        admins[0] = admin;
        admins[1] = owner;

        escrowProxy = new EscrowProxy(address(escrowLogic), admins);
        escrowProxyAsLogic = EscrowLogic(address(escrowProxy));

        // Add test token support
        escrowProxyAsLogic.addAssetSupport(address(testToken), MINIMUM_TOTAL_BUDGET);

        console.log("Proxy address:", address(escrowProxy));
        console.log("Logic implementation:", address(escrowLogic));
        console.log("Implementation from proxy:", escrowProxy.get_implementation());
        console.log("Owner:", owner);
    }

    function testCreateRequestWithNativeToken() public {
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit YapRequestCreated(1, user1, NATIVE_TOKEN, REQUEST_BUDGET, FEE);

        (uint256 yapId, uint256 exactBudget,,, address asset) = escrowProxyAsLogic.createRequest{
            value: TOTAL_REQUEST_BUDGET
        }(
            1, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId"
        );

        vm.stopPrank();

        assertEq(yapId, 1);
        assertEq(exactBudget, REQUEST_BUDGET);
        assertEq(asset, NATIVE_TOKEN);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);
        assertEq(yapRequest.creator, user1);
        assertEq(yapRequest.budget, REQUEST_BUDGET);
        assertEq(yapRequest.asset, NATIVE_TOKEN);
        assertTrue(yapRequest.isActive);

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance(NATIVE_TOKEN);
        assertEq(feeBalance, FEE);
    }

    function testCreateRequestWithERC20Token() public {
        vm.startPrank(user1);

        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);

        vm.expectEmit(true, true, false, true);
        emit YapRequestCreated(1, user1, address(testToken), REQUEST_BUDGET, FEE);

        (uint256 yapId, uint256 exactBudget,,, address asset) =
            escrowProxyAsLogic.createRequest(2, REQUEST_BUDGET, FEE, address(testToken), "randomId");

        vm.stopPrank();

        assertEq(yapId, 1);
        assertEq(exactBudget, REQUEST_BUDGET);
        assertEq(asset, address(testToken));

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(1);
        assertEq(yapRequest.creator, user1);
        assertEq(yapRequest.budget, REQUEST_BUDGET);
        assertEq(yapRequest.asset, address(testToken));
        assertTrue(yapRequest.isActive);

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance(address(testToken));
        assertEq(feeBalance, FEE);
    }

    function testRewardYapWinnersWithNativeToken() public {
        // Create request with native ETH
        vm.startPrank(user1);
        uint256 user1InitialBalance = user1.balance;
        (uint256 yapId,,,,) = escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET}(
            3, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId"
        );
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = winner1;
        winners[1] = winner2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = REWARD_AMOUNT;
        rewards[1] = REWARD_AMOUNT;

        uint256 winner1InitialBalance = winner1.balance;
        uint256 winner2InitialBalance = winner2.balance;

        vm.startPrank(admin);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();

        assertEq(winner1.balance, winner1InitialBalance + REWARD_AMOUNT);
        assertEq(winner2.balance, winner2InitialBalance + REWARD_AMOUNT);

        uint256 expectedRefund = REQUEST_BUDGET - (REWARD_AMOUNT * 2);
        uint256 expectedFinalBalance = user1InitialBalance - TOTAL_REQUEST_BUDGET + expectedRefund;
        assertEq(user1.balance, expectedFinalBalance);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);
    }

    function testRewardYapWinnersWithERC20Token() public {
        vm.startPrank(user1);
        uint256 user1InitialBalance = testToken.balanceOf(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,,) = escrowProxyAsLogic.createRequest(4, REQUEST_BUDGET, FEE, address(testToken), "randomId");
        vm.stopPrank();

        address[] memory winners = new address[](2);
        winners[0] = winner1;
        winners[1] = winner2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = REWARD_AMOUNT;
        rewards[1] = REWARD_AMOUNT;

        uint256 winner1InitialBalance = testToken.balanceOf(winner1);
        uint256 winner2InitialBalance = testToken.balanceOf(winner2);

        vm.startPrank(admin);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();

        assertEq(testToken.balanceOf(winner1), winner1InitialBalance + REWARD_AMOUNT);
        assertEq(testToken.balanceOf(winner2), winner2InitialBalance + REWARD_AMOUNT);

        uint256 expectedRefund = REQUEST_BUDGET - (REWARD_AMOUNT * 2);
        uint256 expectedFinalBalance = user1InitialBalance - TOTAL_REQUEST_BUDGET + expectedRefund;
        assertEq(testToken.balanceOf(user1), expectedFinalBalance);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, 0);
        assertFalse(yapRequest.isActive);
    }

    function testTopUpRequestWithNativeToken() public {
        vm.startPrank(user1);
        (uint256 yapId,,,,) = escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET}(
            5, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId"
        );

        (, uint256 newTotalBudget,,,) =
            escrowProxyAsLogic.topUpRequest{value: TOTAL_REQUEST_BUDGET}(yapId, REQUEST_BUDGET, FEE);
        vm.stopPrank();

        assertEq(newTotalBudget, REQUEST_BUDGET * 2);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, REQUEST_BUDGET * 2);
        assertTrue(yapRequest.isActive);
    }

    function testTopUpRequestWithERC20Token() public {
        vm.startPrank(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET * 2);
        (uint256 yapId,,,,) = escrowProxyAsLogic.createRequest(6, REQUEST_BUDGET, FEE, address(testToken), "randomId");

        (, uint256 newTotalBudget,,,) = escrowProxyAsLogic.topUpRequest(yapId, REQUEST_BUDGET, FEE);
        vm.stopPrank();

        assertEq(newTotalBudget, REQUEST_BUDGET * 2);

        EscrowLogic.YapRequest memory yapRequest = escrowProxyAsLogic.getYapRequest(yapId);
        assertEq(yapRequest.budget, REQUEST_BUDGET * 2);
        assertTrue(yapRequest.isActive);
    }

    function testWithdrawFeesNativeToken() public {
        vm.startPrank(user1);
        escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET}(7, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId");
        vm.stopPrank();

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance(NATIVE_TOKEN);
        assertEq(feeBalance, FEE);

        address feeReceiver = makeAddr("feeReceiver");
        uint256 initialBalance = feeReceiver.balance;

        escrowProxyAsLogic.withdrawFees(feeReceiver, feeBalance, NATIVE_TOKEN);

        uint256 newFeeBalance = escrowProxyAsLogic.getFeeBalance(NATIVE_TOKEN);
        assertEq(newFeeBalance, 0);
        assertEq(feeReceiver.balance, initialBalance + feeBalance);
    }

    function testWithdrawFeesERC20Token() public {
        vm.startPrank(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(8, REQUEST_BUDGET, FEE, address(testToken), "randomId");
        vm.stopPrank();

        uint256 feeBalance = escrowProxyAsLogic.getFeeBalance(address(testToken));
        assertEq(feeBalance, FEE);

        address feeReceiver = makeAddr("feeReceiver");
        uint256 initialBalance = testToken.balanceOf(feeReceiver);

        escrowProxyAsLogic.withdrawFees(feeReceiver, feeBalance, address(testToken));

        uint256 newFeeBalance = escrowProxyAsLogic.getFeeBalance(address(testToken));
        assertEq(newFeeBalance, 0);
        assertEq(testToken.balanceOf(feeReceiver), initialBalance + feeBalance);
    }

    function testAddAssetSupport() public {
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);

        assertFalse(escrowProxyAsLogic.isAssetSupported(address(newToken)));

        escrowProxyAsLogic.addAssetSupport(address(newToken), MINIMUM_TOTAL_BUDGET);

        assertTrue(escrowProxyAsLogic.isAssetSupported(address(newToken)));

        uint256 minBudget = escrowProxyAsLogic.getMinimumBudget(address(newToken));
        assertEq(minBudget, MINIMUM_TOTAL_BUDGET);

        address[] memory allAssets = escrowProxyAsLogic.getAllAssets();
        bool found = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == address(newToken)) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function testRemoveAssetSupport() public {
        // Add new token first
        MockERC20 newToken = new MockERC20("New Token", "NEW", 18);
        escrowProxyAsLogic.addAssetSupport(address(newToken), MINIMUM_TOTAL_BUDGET);
        assertTrue(escrowProxyAsLogic.isAssetSupported(address(newToken)));

        // Remove support
        escrowProxyAsLogic.removeAssetSupport(address(newToken));
        assertFalse(escrowProxyAsLogic.isAssetSupported(address(newToken)));
    }

    function testCannotRemoveNativeToken() public {
        vm.expectRevert(EscrowLogic.CannotRemoveCoreAssets.selector);
        escrowProxyAsLogic.removeAssetSupport(NATIVE_TOKEN);
    }

    function testUpdateAssetRequirements() public {
        uint256 newMinBudget = 200000;
        escrowProxyAsLogic.updateAssetRequirements(address(testToken), newMinBudget);

        uint256 minBudget = escrowProxyAsLogic.getMinimumBudget(address(testToken));
        assertEq(minBudget, newMinBudget);
    }

    function testCreateRequestUnsupportedAssetReverts() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);

        vm.startPrank(user1);
        vm.expectRevert(EscrowLogic.AssetNotSupported.selector);
        escrowProxyAsLogic.createRequest(9, REQUEST_BUDGET, FEE, address(unsupportedToken), "randomId");
        vm.stopPrank();
    }

    function testCreateRequestInsufficientNativeTokenReverts() public {
        vm.startPrank(user1);
        vm.expectRevert(EscrowLogic.InsufficientNativeBalance.selector);
        escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET - 1}(
            10, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId"
        );
        vm.stopPrank();
    }

    function testCreateRequestSendEthForERC20Reverts() public {
        vm.startPrank(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        vm.expectRevert(EscrowLogic.NoEthValueShouldBeSent.selector);
        escrowProxyAsLogic.createRequest{value: 1 ether}(1, REQUEST_BUDGET, FEE, address(testToken), "randomId");
        vm.stopPrank();
    }

    function testExcessEthRefund() public {
        vm.startPrank(user1);
        uint256 initialBalance = user1.balance;
        uint256 excessAmount = 2 ether;

        escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET + excessAmount}(
            2, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId"
        );

        // Should have received refund for excess
        assertEq(user1.balance, initialBalance - TOTAL_REQUEST_BUDGET);
        vm.stopPrank();
    }

    function testGetTotalBalance() public {
        vm.startPrank(user1);
        escrowProxyAsLogic.createRequest{value: TOTAL_REQUEST_BUDGET}(1, REQUEST_BUDGET, FEE, NATIVE_TOKEN, "randomId");
        vm.stopPrank();

        uint256 nativeBalance = escrowProxyAsLogic.getTotalBalance(NATIVE_TOKEN);
        assertEq(nativeBalance, TOTAL_REQUEST_BUDGET);

        vm.startPrank(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        escrowProxyAsLogic.createRequest(1, REQUEST_BUDGET, FEE, address(testToken), "randomId");
        vm.stopPrank();

        uint256 tokenBalance = escrowProxyAsLogic.getTotalBalance(address(testToken));
        assertEq(tokenBalance, TOTAL_REQUEST_BUDGET);
    }

    function testUpgradeImplementation() public {
        EscrowLogic newImpl = new EscrowLogic();

        address currentImpl = escrowProxy.get_implementation();
        assertEq(currentImpl, address(escrowLogic));

        vm.prank(owner);
        escrowProxy.upgradeTo(address(newImpl));

        address updatedImpl = escrowProxy.get_implementation();
        assertEq(updatedImpl, address(newImpl));
    }

    function testRewardYapWinnersNonAdminReverts() public {
        vm.startPrank(user1);
        testToken.approve(address(escrowProxy), TOTAL_REQUEST_BUDGET);
        (uint256 yapId,,,,) = escrowProxyAsLogic.createRequest(3, REQUEST_BUDGET, FEE, address(testToken), "randomId");
        vm.stopPrank();

        address[] memory winners = new address[](1);
        winners[0] = winner1;
        uint256[] memory rewards = new uint256[](1);
        rewards[0] = REWARD_AMOUNT;

        vm.startPrank(user2);
        vm.expectRevert(EscrowLogic.OnlyAdminsCanDistributeRewards.selector);
        escrowProxyAsLogic.rewardYapWinners(yapId, winners, rewards, true);
        vm.stopPrank();
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

    function testGetAllAssets() public view {
        address[] memory assets = escrowProxyAsLogic.getAllAssets();

        // Should contain native token and test token
        assertEq(assets.length, 2);
        assertEq(assets[0], NATIVE_TOKEN);
        assertEq(assets[1], address(testToken));
    }

    // Helper function to add new view functions if needed
    function isAssetSupported(address asset) public view returns (bool) {
        // This would call the view function once it's added to the contract
        try escrowProxyAsLogic.isAssetSupported(asset) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function getMinimumBudget(address asset) public view returns (uint256) {
        // This would call the view function once it's added to the contract
        try escrowProxyAsLogic.getMinimumBudget(asset) returns (uint256 minBudget) {
            return minBudget;
        } catch {
            return 0;
        }
    }
}

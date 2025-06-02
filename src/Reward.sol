// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    address private kaitoTokenAddress;
    mapping(uint256 => address[]) private s_yap_winners;
    mapping(uint256 => uint256[]) private s_yap_winners_amount;
    mapping(address => bool) private s_is_admin;

    event RewardsDistributed(uint256 indexed yapId, address[] winners, uint256 rewardPerWinner);
    event BalanceWithdrawn(address indexed to, address indexed caller, uint256 amount);

    error ValueMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error NoWinnersProvided();
    error InvalidWinnersProvided();
    error TokenTransferFailed();
    error InvalidERC20Address();
    error InsufficientBudget();
    error OnlyAdminsCanDistributeRewards();

    constructor(address _kaitoAddress, address[] memory _admins) Ownable(msg.sender) {
        s_is_admin[msg.sender] = true;
        kaitoTokenAddress = _kaitoAddress;

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }
    }

    /**
     * @notice Distributes rewards to winners of a yap request
     * @param yapRequestId The ID of the yap request
     * @param winners Array of winner addresses
     * @param winnersRewards Array of corresponding reward amounts for each winner
     */
    function rewardYapWinners(uint256 yapRequestId, address[] calldata winners, uint256[] calldata winnersRewards)
        external
        nonReentrant
    {
        uint256 winnerslength = winners.length;
        uint256 winnersRewardsLength = winnersRewards.length;
        if (winnerslength == 0 || winnersRewardsLength == 0) {
            revert NoWinnersProvided();
        }

        if (winnerslength != winnersRewardsLength) {
            revert InvalidWinnersProvided();
        }

        if (!s_is_admin[msg.sender]) {
            revert OnlyAdminsCanDistributeRewards();
        }

        uint256 totalReward = 0;
        for (uint256 i = 0; i < winnersRewardsLength; i++) {
            totalReward += winnersRewards[i];
        }

        uint256 balance = IERC20(kaitoTokenAddress).balanceOf(address(this));

        if (totalReward > balance) {
            revert InsufficientBudget();
        }

        for (uint256 i = 0; i < winnerslength; i++) {
            s_yap_winners[yapRequestId].push(winners[i]);
            s_yap_winners_amount[yapRequestId].push(winnersRewards[i]);
            IERC20(kaitoTokenAddress).safeTransfer(winners[i], winnersRewards[i]);
        }

        emit RewardsDistributed(yapRequestId, winners, totalReward);
    }

    /**
     * @notice Gets the winners for yap requests
     * @return Array of the winners of a yap requests
     */
    function getWinners(uint256 yapRequestId) external view returns (address[] memory) {
        return s_yap_winners[yapRequestId];
    }

    function getWinnersAmounts(uint256 yapRequestId) external view returns (uint256[] memory) {
        return s_yap_winners_amount[yapRequestId];
    }

    function getBalance() public view returns (uint256) {
        return IERC20(kaitoTokenAddress).balanceOf(address(this));
    }

    function withdrawBalance(address to) public nonReentrant onlyOwner {
        uint256 balance = IERC20(kaitoTokenAddress).balanceOf(address(this));

        if (balance > 0) {
            IERC20(kaitoTokenAddress).safeTransfer(to, balance);

            emit BalanceWithdrawn(to, msg.sender, balance);
        }
    }

    function addAdmin(address newAdmin) public onlyOwner {
        s_is_admin[newAdmin] = true;
    }

    /**
     * @notice Checks if an address is an admin
     * @return bool indicating if the address is an admin
     */
    function isAdmin(address _address) external view returns (bool) {
        return s_is_admin[_address];
    }
}

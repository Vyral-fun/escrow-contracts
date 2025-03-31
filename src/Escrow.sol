// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 private s_yapRequestCount = 0;
    address private kaitoTokenAddress;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yap_winners;
    mapping(address => bool) private s_is_admin;

    enum RequesterType {
        Project,
        Individual
    }

    struct YapRequest {
        uint256 yapId;
        address creator;
        uint256 budget;
        bool isActive;
    }

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget);
    event RewardsDistributed(uint256 indexed yapId, address[] winners, uint256 rewardPerWinner);

    error ValueMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error NoWinnersProvided();
    error InvalidWinnersProvided();
    error TokenTransferFailed();
    error NativeTransferFailed();
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
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget) external nonReentrant returns (uint256) {
        if (_budget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        if (msg.sender == address(0)) {
            revert InvalidYapRequestId();
        }

        IERC20(kaitoTokenAddress).safeTransferFrom(msg.sender, address(this), _budget);

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] =
            YapRequest({yapId: s_yapRequestCount, creator: msg.sender, budget: _budget, isActive: true});

        emit YapRequestCreated(s_yapRequestCount, msg.sender, _budget);

        return s_yapRequestCount;
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

        YapRequest memory yapRequest = s_yapRequests[yapRequestId];

        if (yapRequest.yapId == 0) {
            revert InvalidYapRequestId();
        }

        if (!yapRequest.isActive) {
            revert YapRequestNotActive();
        }

        if (!s_is_admin[msg.sender]) {
            revert OnlyAdminsCanDistributeRewards();
        }

        uint256 totalReward = 0;
        for (uint256 i = 0; i < winnersRewardsLength; i++) {
            totalReward += winnersRewards[i];
        }

        if (totalReward > yapRequest.budget) {
            revert InsufficientBudget();
        }

        s_yapRequests[yapRequestId].isActive = false;

        for (uint256 i = 0; i < winnerslength; i++) {
            s_yap_winners[yapRequestId].push(winners[i]);
            IERC20(kaitoTokenAddress).safeTransfer(winners[i], winnersRewards[i]);
        }

        emit RewardsDistributed(yapRequestId, winners, totalReward);
    }

    /**
     * @notice Gets a yap request by ID
     * @param yapRequestId The ID of the yap request
     * @return The yap request details
     */
    function getYapRequest(uint256 yapRequestId) external view returns (YapRequest memory) {
        YapRequest memory yapRequest = s_yapRequests[yapRequestId];
        if (yapRequest.yapId == 0) {
            revert YapRequestNotFound();
        }
        return yapRequest;
    }

    /**
     * @notice Gets the total number of yap requests
     * @return The total number of yap requests
     */
    function getTotalYapRequests() external view returns (uint256) {
        return s_yapRequestCount;
    }

    /**
     * @notice Gets the winners for yap requests
     * @return Array of the winners of a yap requests
     */
    function getWinners(uint256 yapRequestId) external view returns (address[] memory) {
        return s_yap_winners[yapRequestId];
    }

    /**
     * @notice Checks if an address is an admin
     * @return bool indicating if the address is an admin
     */
    function isAdmin(address _address) external view returns (bool) {
        return s_is_admin[_address];
    }
}

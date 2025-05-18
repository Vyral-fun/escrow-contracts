// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EscrowLogic is Initializable, OwnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private s_yapRequestCount;
    uint256 private s_feeBalance;
    address private kaitoTokenAddress;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yapWinners;
    mapping(address => bool) private s_is_admin;

    struct YapRequest {
        uint256 yapId;
        address creator;
        uint256 budget;
        bool isActive;
    }

    struct ApprovedWinner {
        address winner;
        uint256 amount;
        uint256 approvalTime;
    }

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget, uint256 fee);
    event WinnerApproved(uint256 indexed yapId, address winner, uint256 amount);
    event Initialized(address kaitoAddress, address[] admins);
    event Claimed(uint256 indexed yapId, address winner, uint256 amount);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);

    error OnlyAdminsCanDistributeRewards();
    error NoWinnersProvided();
    error FeeMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error InvalidWinnersProvided();
    error InvalidERC20Address();
    error InsufficientBudget();
    error AlreadyInitialized();
    error NotAdmin();

    function initialize(address _kaitoAddress, address[] memory _admins, uint256 _currentYapRequestCount)
        public
        initializer
    {
        __Ownable_init(msg.sender);

        if (kaitoTokenAddress != address(0)) {
            revert AlreadyInitialized();
        }

        s_yapRequestCount = _currentYapRequestCount;
        s_is_admin[msg.sender] = true;
        s_feeBalance = 0;
        kaitoTokenAddress = _kaitoAddress;

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }

        emit Initialized(_kaitoAddress, _admins);
    }

    /**
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @param _fee The fee from the yap budget (1% = 1000, 0.75% = 750)
     * @dev The fee must be greater than zero
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget, uint256 _fee) external returns (uint256, uint256, uint256, address) {
        if (_budget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        if (_fee == 0) {
            revert FeeMustBeGreaterThanZero();
        }

        uint256 total = _budget + _fee;
        IERC20(kaitoTokenAddress).safeTransferFrom(msg.sender, address(this), total);

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] =
            YapRequest({yapId: s_yapRequestCount, creator: msg.sender, budget: _budget, isActive: true});

        s_feeBalance += _fee;
        emit YapRequestCreated(s_yapRequestCount, msg.sender, _budget, _fee);

        return (s_yapRequestCount, _budget, _fee, msg.sender);
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
        if (!s_is_admin[msg.sender]) {
            revert OnlyAdminsCanDistributeRewards();
        }

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

        uint256 totalReward = 0;
        for (uint256 i = 0; i < winnersRewardsLength; i++) {
            totalReward += winnersRewards[i];
        }

        if (totalReward > yapRequest.budget) {
            revert InsufficientBudget();
        }

        s_yapRequests[yapRequestId].budget -= totalReward;

        if (s_yapRequests[yapRequestId].budget == 0) {
            s_yapRequests[yapRequestId].isActive = false;
        }

        for (uint256 i = 0; i < winnerslength; i++) {
            s_yapWinners[yapRequestId].push(winners[i]);
            IERC20(kaitoTokenAddress).safeTransfer(winners[i], winnersRewards[i]);
        }

        emit RewardsDistributed(yapRequestId, winners, totalReward);
    }

    /**
     * @notice Withdraw accumulated fees
     * @param to The address to send fees to
     * @param amount The amount of fees to withdraw
     */
    function withdrawFees(address to, uint256 amount) external onlyOwner {
        if (amount > s_feeBalance) {
            revert InsufficientBudget();
        }
        s_feeBalance -= amount;
        IERC20(kaitoTokenAddress).safeTransfer(to, amount);
    }

    /**
     * @notice Resets the token address yap reward
     * @param _newTokenAddress The new token address
     */
    function resetKaitoAddress(address _newTokenAddress) external onlyOwner {
        if (_newTokenAddress == address(0)) {
            revert InvalidERC20Address();
        }
        kaitoTokenAddress = _newTokenAddress;
    }

    /**
     * @notice Gets the fee balance
     * @return The current fee balance
     */
    function getFeeBalance() external view returns (uint256) {
        return (s_feeBalance);
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
        return s_yapWinners[yapRequestId];
    }

    /**
     * @notice Gets the address of the Kaito token
     * @return The address of the Kaito token
     */
    function getKaitoAddress() external view returns (address) {
        return kaitoTokenAddress;
    }
    /**
     * @notice Checks if an address is an admin
     * @return bool indicating if the address is an admin
     */

    function isAdmin(address _address) external view returns (bool) {
        return s_is_admin[_address];
    }

    /**
     * @notice Add a new admin
     * @param _admin Address of the new admin
     */
    function addAdmin(address _admin) external onlyOwner {
        s_is_admin[_admin] = true;
    }

    /**
     * @notice Remove an admin
     * @param _admin Address of the admin to remove
     */
    function removeAdmin(address _admin) external onlyOwner {
        s_is_admin[_admin] = false;
    }

    modifier onlyAdmin() {
        if (!s_is_admin[msg.sender]) {
            revert NotAdmin();
        }
        _;
    }
}

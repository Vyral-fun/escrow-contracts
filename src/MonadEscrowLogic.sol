// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EscrowLogic is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 private s_yapRequestCount;
    uint256 private s_feeBalance;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yapWinners;
    mapping(address => bool) private s_is_admin;
    uint256 private MINIMUM_FEE = 500000000000000000000;
    uint256 private MINIMUM_BUDGET = 4500000000000000000000;

    uint256[50] private __gap;

    struct YapRequest {
        uint256 yapId;
        address creator;
        uint256 budget;
        bool isActive;
    }

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget, uint256 fee);
    event Initialized(address[] admins, uint256 currentYapRequestCount, address owner);
    event Claimed(uint256 indexed yapId, address winner, uint256 amount);
    event AdminAdded(address indexed admin, address indexed addedBy);
    event AdminRemoved(address indexed admin, address indexed removedBy);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event CreatorRefunded(uint256 indexed yapRequestId, address creator, uint256 budgetLeft);
    event YapRequestCountReset(uint256 newYapRequestCount);
    event MinimumFeeReset(uint256 newMinimumFee);
    event MinimumBudgetReset(uint256 newMinimumBudget);
    event YapRequestTopUp(
        uint256 indexed yapId, address indexed creator, uint256 additionalBudget, uint256 additionalFee
    );

    error OnlyAdminsCanDistributeRewards();
    error NoWinnersProvided();
    error FeeMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error InvalidValue();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error InvalidWinnersProvided();
    error InsufficientBudget();
    error NotAdmin();
    error NotTheCreator();

    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory _admins, uint256 _currentYapRequestCount, address initialOwner)
        public
        initializer
    {
        __Ownable2Step_init();

        _transferOwnership(initialOwner);
        s_yapRequestCount = _currentYapRequestCount;
        s_is_admin[msg.sender] = true;

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }

        emit Initialized(_admins, _currentYapRequestCount, initialOwner);
    }

    /**
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @param _fee The fee from the yap budget (1% = 1000, 0.75% = 750)
     * @dev The fee must be greater than zero
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget, uint256 _fee)
        external
        payable
        nonReentrant
        returns (uint256, uint256, uint256, address)
    {
        if (_budget == 0 || _budget < MINIMUM_BUDGET) {
            revert BudgetMustBeGreaterThanZero();
        }
        if (_fee == 0 || _fee < MINIMUM_FEE) {
            revert FeeMustBeGreaterThanZero();
        }

        uint256 total = _budget + _fee;

        if (msg.value < total) {
            revert InvalidValue();
        }

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] =
            YapRequest({yapId: s_yapRequestCount, creator: msg.sender, budget: _budget, isActive: true});

        s_feeBalance += _fee;
        emit YapRequestCreated(s_yapRequestCount, msg.sender, _budget, _fee);

        return (s_yapRequestCount, _budget, _fee, msg.sender);
    }

    /**
     * @notice Top up an existing yap request with additional budget and fee
     * @param yapRequestId The ID of the yap request to top up
     * @param additionalBudget The additional budget to add to the yap request
     * @param additionalFee The additional fee to add to the yap request
     * @dev The total budget (additionalBudget + additionalFee) must be greater than the minimum budget for the asset
     * @return The updated yap request details
     */
    function topUpRequest(uint256 yapRequestId, uint256 additionalBudget, uint256 additionalFee)
        external
        payable
        nonReentrant
        returns (uint256, uint256, uint256, address)
    {
        uint256 total = additionalBudget + additionalFee;

        if (additionalFee == 0 || additionalFee < MINIMUM_FEE) {
            revert FeeMustBeGreaterThanZero();
        }

        if (additionalBudget == 0 || additionalBudget < MINIMUM_BUDGET) {
            revert BudgetMustBeGreaterThanZero();
        }

        YapRequest storage yapRequest = s_yapRequests[yapRequestId];
        if (yapRequest.creator != msg.sender) {
            revert NotTheCreator();
        }

        if (yapRequest.yapId == 0) {
            revert InvalidYapRequestId();
        }

        if (!yapRequest.isActive) {
            revert YapRequestNotActive();
        }

        if (msg.value < total) {
            revert InvalidValue();
        }

        s_feeBalance += additionalFee;
        yapRequest.budget += additionalBudget;

        emit YapRequestTopUp(yapRequest.yapId, yapRequest.creator, additionalBudget, additionalFee);

        return (yapRequestId, yapRequest.budget, additionalFee, msg.sender);
    }

    /**
     * @notice Distributes rewards to winners of a yap request
     * @param yapRequestId The ID of the yap request
     * @param winners Array of winner addresses
     * @param winnersRewards Array of corresponding reward amounts for each winner
     * @param isLastBatch Indicates if this is the last batch of winners
     */
    function rewardYapWinners(
        uint256 yapRequestId,
        address[] calldata winners,
        uint256[] calldata winnersRewards,
        bool isLastBatch
    ) external nonReentrant {
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

        for (uint256 i = 0; i < winnerslength; i++) {
            s_yapWinners[yapRequestId].push(winners[i]);
            (bool sent,) = winners[i].call{value: winnersRewards[i]}("");
            require(sent, "Failed to send Ether");
        }

        if (isLastBatch) {
            uint256 budgetLeft = s_yapRequests[yapRequestId].budget;
            if (budgetLeft > 0) {
                (bool sent,) = yapRequest.creator.call{value: budgetLeft}("");
                require(sent, "Failed to send Ether");

                emit CreatorRefunded(yapRequestId, yapRequest.creator, budgetLeft);
            }

            s_yapRequests[yapRequestId].budget = 0;
            s_yapRequests[yapRequestId].isActive = false;
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
        (bool sent,) = to.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @notice Resets the yap request count
     * @param newYapRequstCount The new yap request count
     */
    function resetYapRequestCount(uint256 newYapRequstCount) external onlyOwner {
        if (newYapRequstCount == 0) {
            revert InvalidYapRequestId();
        }
        s_yapRequestCount = newYapRequstCount;

        emit YapRequestCountReset(newYapRequstCount);
    }

    /**
     * @notice Resets the minimum fee for yap requests
     * @param newMinimumFee The new minimum fee
     * @dev The new minimum fee must be greater than zero
     */
    function resetMinimumFee(uint256 newMinimumFee) external onlyOwner {
        if (newMinimumFee == 0) {
            revert FeeMustBeGreaterThanZero();
        }
        MINIMUM_FEE = newMinimumFee;

        emit MinimumFeeReset(newMinimumFee);
    }

    /**
     * @notice Resets the minimum budget for yap requests
     * @param newMinimumBudget The new minimum budget
     * @dev The new minimum budget must be greater than zero
     */
    function resetMinimumBudget(uint256 newMinimumBudget) external onlyOwner {
        if (newMinimumBudget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        MINIMUM_BUDGET = newMinimumBudget;

        emit MinimumBudgetReset(newMinimumBudget);
    }

    /**
     * @notice Gets the fee balance
     * @return The current fee balance
     */
    function getFeeBalance() external view returns (uint256) {
        return (s_feeBalance);
    }

    /**
     * @notice Gets the total balance of the contract
     * @return The total balance of the contract in Kaito tokens
     */
    function getTotalBalance() external view returns (uint256) {
        return address(this).balance;
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
        emit AdminAdded(_admin, msg.sender);
    }

    /**
     * @notice Remove an admin
     * @param _admin Address of the admin to remove
     */
    function removeAdmin(address _admin) external onlyOwner {
        s_is_admin[_admin] = false;
        emit AdminRemoved(_admin, msg.sender);
    }
}

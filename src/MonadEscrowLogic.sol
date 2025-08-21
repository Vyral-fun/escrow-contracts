// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EscrowLogic is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint32 private s_yapRequestCount;
    uint256 private s_feeBalance;
    mapping(uint32 => YapRequest) private s_yapRequests;
    mapping(uint32 => address[]) private s_yapWinners;
    mapping(address => bool) private s_is_admin;
    uint256 private NETWORK_CHAIN_ID;
    uint256 private MINIMUM_FEE = 500;
    uint256 private MINIMUM_BUDGET = 45000;


    uint256[50] private __gap;

    struct YapRequest {
        uint32 yapId;
        address creator;
        uint256 budget;
        bool isActive;
    }

    event YapRequestCreated(uint32 indexed yapId, address indexed creator, uint256 budget, uint256 fee);
    event Initialized(address[] admins, uint32 currentYapRequestCount, address owner);
    event Claimed(uint32 indexed yapId, address winner, uint256 amount);
    event AdminAdded(address indexed admin, address indexed addedBy);
    event AdminRemoved(address indexed admin, address indexed removedBy);
    event RewardsDistributed(uint32 indexed yapRequestId, address[] winners, uint256 totalReward);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event CreatorRefunded(uint32 indexed yapRequestId, address creator, uint256 budgetLeft);
    event YapRequestCountReset(uint32 newYapRequestCount);
    event MinimumFeeReset(uint256 newMinimumFee);
    event MinimumBudgetReset(uint256 newMinimumBudget);
    event YapRequestTopUp(
        uint32 indexed yapId, address indexed creator, uint256 additionalBudget, uint256 additionalFee
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

    function initialize(address[] memory _admins, uint32 _currentYapRequestCount, address initialOwner)
        public
        initializer
    {
        __Ownable2Step_init();

        _transferOwnership(initialOwner);
        s_yapRequestCount = _currentYapRequestCount;
        s_is_admin[msg.sender] = true;
        NETWORK_CHAIN_ID = block.chainid;

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
        returns (uint32, uint256, uint256, address)
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
        uint32 escrowYapId = (uint32(NETWORK_CHAIN_ID) << 20) | uint32(s_yapRequestCount);
        s_yapRequests[escrowYapId] =
            YapRequest({yapId: escrowYapId, creator: msg.sender, budget: _budget, isActive: true});

        s_feeBalance += _fee;
        emit YapRequestCreated(escrowYapId, msg.sender, _budget, _fee);

        return (escrowYapId, _budget, _fee, msg.sender);
    }

    /**
     * @notice Top up an existing yap request with additional budget and fee
     * @param yapRequestId The ID of the yap request to top up
     * @param additionalBudget The additional budget to add to the yap request
     * @param additionalFee The additional fee to add to the yap request
     * @dev The total budget (additionalBudget + additionalFee) must be greater than the minimum budget for the asset
     * @return The updated yap request details
     */
    function topUpRequest(uint32 yapRequestId, uint256 additionalBudget, uint256 additionalFee)
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
        uint32 yapRequestId,
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
     * @param newYapRequestCount The new yap request count
     */
    function resetYapRequestCount(uint32 newYapRequestCount) external onlyOwner {
        if (newYapRequestCount == 0) {
            revert InvalidYapRequestId();
        }
        s_yapRequestCount = newYapRequestCount;

        emit YapRequestCountReset(newYapRequestCount);
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
    function getYapRequest(uint32 yapRequestId) external view returns (YapRequest memory) {
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
    function getWinners(uint32 yapRequestId) external view returns (address[] memory) {
        return s_yapWinners[yapRequestId];
    }

    /**
     * @notice Gets the network chain ID
     * @return The current network chain ID
     */
    function getNetworkChainId() external view returns (uint32, uint32, uint256) {
        uint32 chainid = uint32(NETWORK_CHAIN_ID & 0xFFF);
        return (chainid, NETWORK_CHAIN_ID);
    }

    /**
     * @notice Generates a unique yap ID based on the current chain ID and yap request count
     * @param yapRequestCount The current yap request count
     * @return The generated yap ID
     */
    function getEscrowYapId(uint32 yapRequestCount) external view returns (uint32) {
        return (uint32(NETWORK_CHAIN_ID) << 20) | uint32(yapRequestCount);
    }

    /**
     * @notice Checks if an addreI want it to be u32ss is an admin
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

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
    uint256 private s_rewardBufferTime;
    uint256 private s_feeBalance;
    address private kaitoTokenAddress;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yap_winners;
    mapping(address => bool) private s_is_admin;
    mapping(uint256 => mapping(address => ApprovedWinner)) private s_yapWinnersApprovals; // yapId => (winner => ApprovedWinner)

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

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, uint256 budget);
    event WinnerApproved(uint256 indexed yapId, address winner, uint256 amount);
    event Initialized(address kaitoAddress, address[] admins);
    event Claimed(uint256 indexed yapId, address winner, uint256 amount);

    error FeeMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error CannotClaimYet();
    error WinnerAlreadyApproved();
    error NotAValidApproval();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error NoValidWinnerProvided();
    error InvalidWinnersProvided();
    error TokenTransferFailed();
    error NativeTransferFailed();
    error InvalidERC20Address();
    error InsufficientBudget();
    error OnlyAdminsCanApproveWinners();
    error AlreadyInitialized();
    error NotAdmin();
    error NotOwner();

    function initialize(
        address _kaitoAddress,
        address[] memory _admins,
        uint256 _bufferTime,
        uint256 _currentYapRequestCount
    ) public initializer {
        __Ownable_init(msg.sender);

        if (kaitoTokenAddress != address(0)) {
            revert AlreadyInitialized();
        }

        s_yapRequestCount = _currentYapRequestCount;
        s_rewardBufferTime = _bufferTime * 1 days;
        s_is_admin[msg.sender] = true;
        s_feeBalance = 0;
        kaitoTokenAddress = _kaitoAddress;

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }

        emit Initialized(_kaitoAddress, _admins);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @param _fee The fee for the yap request
     * @dev The fee must be greater than zero
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget, uint256 _fee) external returns (uint256) {
        if (_budget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        if (_fee == 0) {
            revert FeeMustBeGreaterThanZero();
        }

        uint256 totalBudget = _budget + _fee;
        IERC20(kaitoTokenAddress).safeTransferFrom(msg.sender, address(this), totalBudget);
        s_feeBalance += _fee;

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] =
            YapRequest({yapId: s_yapRequestCount, creator: msg.sender, budget: _budget, isActive: true});

        emit YapRequestCreated(s_yapRequestCount, msg.sender, _budget);

        return s_yapRequestCount;
    }

    /**
     * @notice Approves a winner for a yap request
     * @param yapRequestId The ID of the yap request
     * @param winner The address of the winner
     * @param amount The amount to be rewarded to the winner
     * @dev The budget must be greater than zero
     * @dev The winner must be a valid address
     * @dev The amount must be greater than zero
     * @dev The yap request must be active
     */
    function approveYapWinner(uint256 yapRequestId, address winner, uint256 amount) external onlyAdmin {
        YapRequest memory yapRequest = s_yapRequests[yapRequestId];

        if (yapRequest.budget == 0 && yapRequest.isActive) {
            s_yapRequests[yapRequestId].isActive = false;
            revert InsufficientBudget();
        }

        if (s_yapWinnersApprovals[yapRequestId][winner].approvalTime > 0) {
            revert WinnerAlreadyApproved();
        }

        if (winner == address(0)) {
            revert NoValidWinnerProvided();
        }

        if (amount == 0) {
            revert BudgetMustBeGreaterThanZero();
        }

        if (!yapRequest.isActive) {
            revert YapRequestNotActive();
        }

        if (yapRequest.budget < amount) {
            revert InsufficientBudget();
        }

        s_yapRequests[yapRequestId].budget -= amount;

        if (s_yapRequests[yapRequestId].budget == 0) {
            s_yapRequests[yapRequestId].isActive = false;
        }
        s_yapWinnersApprovals[yapRequestId][winner] =
            ApprovedWinner({winner: winner, amount: amount, approvalTime: block.timestamp});
        s_yap_winners[yapRequestId].push(winner);

        emit WinnerApproved(yapRequestId, winner, amount);
    }

    function claimYapWinners(uint256 yapRequestId) external nonReentrant {
        ApprovedWinner memory approvedWinner = s_yapWinnersApprovals[yapRequestId][msg.sender];

        if (block.timestamp < approvedWinner.approvalTime + s_rewardBufferTime) {
            revert CannotClaimYet();
        }

        if (approvedWinner.winner == address(0)) {
            revert NotAValidApproval();
        }

        uint256 amount = approvedWinner.amount;
        s_yapWinnersApprovals[yapRequestId][msg.sender].amount = 0;
        s_yapWinnersApprovals[yapRequestId][msg.sender].winner = address(0);

        IERC20(kaitoTokenAddress).safeTransfer(msg.sender, amount);

        emit Claimed(yapRequestId, msg.sender, amount);
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
     * @notice Sets the buffer time for claiming rewards
     * @param newBufferTime The new buffer time in seconds
     */
    function resetBufferTime(uint256 newBufferTime) external onlyAdmin {
        s_rewardBufferTime = newBufferTime;
    }

    /**
     * @notice Resets the token address yap reward
     * @param _newTokenAddress The new token address
     */
    function resetKaitoAddress(address _newTokenAddress) external onlyOwner {
        kaitoTokenAddress = _newTokenAddress;
    }

    /**
     * @notice Gets the current buffer time
     * @return The current buffer time in seconds
     */
    function getBufferTime() external view returns (uint256) {
        return s_rewardBufferTime;
    }

    /**
     * @notice Gets the fee balance
     * @return The current fee balance
     */
    function getFeeBalance() external view returns (uint256) {
        return s_feeBalance;
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

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
    address[] private s_allAssets;
    address private constant NATIVE_TOKEN = address(0);
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yapWinners;
    mapping(address => bool) private s_is_admin;

    mapping(address => bool) private s_supportedAssets; // address(0) = native ETH
    mapping(address => uint256) private s_feeBalances; // fee balances per token

    mapping(address => uint256) private s_minimumTotalBudget; // minimum budget per token

    struct YapRequest {
        uint256 yapId;
        address creator;
        uint256 budget;
        uint256 fee;
        address asset;
        bool isActive;
    }

    uint256[50] private __gap;

    event YapRequestCreated(uint256 indexed yapId, address indexed creator, address asset, uint256 budget, uint256 fee);
    event Initialized(address[] admins);
    event Claimed(uint256 indexed yapId, address winner, uint256 amount);
    event AdminAdded(address indexed admin, address indexed addedBy);
    event AdminRemoved(address indexed admin, address indexed removedBy);
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);
    event AffiliateRewardFromFees(uint256 indexed yapRequestId, address affiliate, uint256 reward);
    event FeesWithdrawn(address indexed to, uint256 amount, address asset);
    event CreatorRefunded(uint256 indexed yapRequestId, address creator, uint256 budgetLeft);
    event YapRequestCountReset(uint256 newYapRequestCount);
    event MinimumFeeReset(uint256 newMinimumFee);
    event MinimumBudgetReset(uint256 newMinimumBudget);
    event YapRequestTopUp(
        uint256 indexed yapId, address indexed creator, uint256 additionalBudget, uint256 additionalFee, address asset
    );
    event AssetAdded(address indexed asset, uint256 minimumBudget);
    event AssetRemoved(address indexed asset);
    event AssetUpdated(address indexed asset, uint256 minimumBudget);

    error OnlyAdminsCanDistributeRewards();
    error NoWinnersProvided();
    error FeeMustBeGreaterThanZero();
    error BudgetMustBeGreaterThanZero();
    error RewardMustBeGreaterThanZero();
    error YapRequestNotFound();
    error YapRequestNotActive();
    error InvalidYapRequestId();
    error InvalidWinnersProvided();
    error InvalidAffiliateAddress();
    error InsufficientBudget();
    error InsufficientFees();
    error NotAdmin();
    error NotTheCreator();
    error AssetNotSupported();
    error AssetAlreadySupported();
    error InsufficientNativeBalance();
    error NoEthValueShouldBeSent();
    error NativeTransferFailed();
    error CannotRemoveCoreAssets();

    constructor() {
        _disableInitializers();
    }

    function initialize(address[] memory _admins, uint256 _currentYapRequestCount, address initialOwner)
        public
        initializer
    {
        __Ownable2Step_init();

        _transferOwnership(initialOwner);
        __ReentrancyGuard_init();
        s_yapRequestCount = _currentYapRequestCount;
        s_is_admin[msg.sender] = true;

        s_supportedAssets[NATIVE_TOKEN] = true;
        s_minimumTotalBudget[NATIVE_TOKEN] = 100000;
        s_allAssets.push(NATIVE_TOKEN);

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }

        emit Initialized(_admins);
    }

    /**
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @param _fee The fee from the yap budget (1% = 1000, 0.75% = 750)
     * @dev The fee must be greater than zero
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget, uint256 _fee, address _asset)
        external
        payable
        nonReentrant
        returns (uint256, uint256, uint256, address, address)
    {
        if (!s_supportedAssets[_asset]) {
            revert AssetNotSupported();
        }

        uint256 total = _budget + _fee;

        uint256 mininumBudget = s_minimumTotalBudget[_asset];

        if (_budget == 0 || _fee == 0 || total < mininumBudget) {
            revert BudgetMustBeGreaterThanZero();
        }

        if (_asset == NATIVE_TOKEN) {
            if (msg.value < total) {
                revert InsufficientNativeBalance();
            }

            if (msg.value > total) {
                (bool success,) = payable(msg.sender).call{value: msg.value - total}("");
                if (!success) {
                    revert NativeTransferFailed();
                }
            }
        } else {
            if (msg.value > 0) {
                revert NoEthValueShouldBeSent();
            }

            IERC20(_asset).safeTransferFrom(msg.sender, address(this), total);
        }

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] = YapRequest({
            yapId: s_yapRequestCount,
            creator: msg.sender,
            budget: _budget,
            fee: _fee,
            asset: _asset,
            isActive: true
        });

        s_feeBalances[_asset] += _fee;
        emit YapRequestCreated(s_yapRequestCount, msg.sender, _asset, _budget, _fee);

        return (s_yapRequestCount, _budget, _fee, msg.sender, _asset);
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
        returns (uint256, uint256, uint256, address, address)
    {
        uint256 total = additionalBudget + additionalFee;
        address asset = s_yapRequests[yapRequestId].asset;

        if (!s_supportedAssets[asset]) {
            revert AssetNotSupported();
        }

        uint256 mininumBudget = s_minimumTotalBudget[asset];

        if (additionalBudget == 0 || additionalFee == 0 || total < mininumBudget) {
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

        if (asset == NATIVE_TOKEN) {
            if (msg.value < total) {
                revert InsufficientNativeBalance();
            }

            if (msg.value > total) {
                (bool success,) = payable(msg.sender).call{value: msg.value - total}("");
                if (!success) {
                    revert NativeTransferFailed();
                }
            }
        } else {
            if (msg.value > 0) {
                revert NoEthValueShouldBeSent();
            }

            IERC20(asset).safeTransferFrom(msg.sender, address(this), total);
        }

        s_feeBalances[asset] += additionalFee;
        yapRequest.budget += additionalBudget;
        yapRequest.fee += additionalFee;

        emit YapRequestTopUp(yapRequest.yapId, yapRequest.creator, additionalBudget, additionalFee, asset);

        return (yapRequestId, yapRequest.budget, additionalFee, msg.sender, asset);
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
            if (yapRequest.asset == NATIVE_TOKEN) {
                (bool success,) = payable(winners[i]).call{value: winnersRewards[i]}("");
                if (!success) {
                    revert NativeTransferFailed();
                }
            } else {
                IERC20(yapRequest.asset).safeTransfer(winners[i], winnersRewards[i]);
            }
        }

        if (isLastBatch) {
            uint256 budgetLeft = s_yapRequests[yapRequestId].budget;
            if (budgetLeft > 0) {
                if (yapRequest.asset == NATIVE_TOKEN) {
                    (bool success,) = payable(yapRequest.creator).call{value: budgetLeft}("");
                    if (!success) {
                        revert NativeTransferFailed();
                    }
                } else {
                    IERC20(yapRequest.asset).safeTransfer(yapRequest.creator, budgetLeft);
                }

                emit CreatorRefunded(yapRequestId, yapRequest.creator, budgetLeft);
            }

            s_yapRequests[yapRequestId].budget = 0;
            s_yapRequests[yapRequestId].isActive = false;
        }

        emit RewardsDistributed(yapRequestId, winners, totalReward);
    }

    /**
     * @notice Distributes fees rewards to affiliate of a yap campaign
     * @param yapRequestId The ID of the yap request
     * @param affiliate affiliate that referred the campaign creator
     * @param reward reward amounts for the affiliate
     */
    function rewardAffiliateFromFees(uint256 yapRequestId, address affiliate, uint256 reward) external nonReentrant {
        if (!s_is_admin[msg.sender]) {
            revert OnlyAdminsCanDistributeRewards();
        }

        if (reward == 0) {
            revert RewardMustBeGreaterThanZero();
        }

        if (affiliate == address(0)) {
            revert InvalidAffiliateAddress();
        }

        YapRequest memory yapRequest = s_yapRequests[yapRequestId];

        if (yapRequest.yapId == 0) {
            revert InvalidYapRequestId();
        }

        if (reward > yapRequest.fee) {
            revert InsufficientFees();
        }

        s_yapRequests[yapRequestId].fee -= reward;
        s_feeBalances[yapRequest.asset] -= reward;
        if (yapRequest.asset == NATIVE_TOKEN) {
            (bool success,) = payable(affiliate).call{value: reward}("");
            if (!success) {
                revert NativeTransferFailed();
            }
        } else {
            IERC20(yapRequest.asset).safeTransfer(affiliate, reward);
        }

        emit AffiliateRewardFromFees(yapRequestId, affiliate, reward);
    }

    /**
     * @notice Withdraw accumulated fees
     * @param to The address to send fees to
     * @param amount The amount of fees to withdraw
     */
    function withdrawFees(address to, uint256 amount, address asset) external onlyOwner nonReentrant {
        if (amount > s_feeBalances[asset]) {
            revert InsufficientBudget();
        }

        s_feeBalances[asset] -= amount;

        if (asset == NATIVE_TOKEN) {
            (bool success,) = payable(to).call{value: amount}("");
            if (!success) {
                revert NativeTransferFailed();
            }
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }

        emit FeesWithdrawn(to, amount, asset);
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
     * @notice Add support for a new asset
     * @param asset The address of the asset to support
     * @param minimumBudget The minimum budget required for the asset
     * @dev The asset must not already be supported, and the minimum budget must be greater than zero
     */
    function addAssetSupport(address asset, uint256 minimumBudget) external onlyOwner {
        if (s_supportedAssets[asset]) {
            revert AssetAlreadySupported();
        }

        if (minimumBudget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }

        s_supportedAssets[asset] = true;
        s_minimumTotalBudget[asset] = minimumBudget;

        uint256 assetCount = s_allAssets.length;
        bool isAdded = false;
        for (uint256 i = 0; i < assetCount; i++) {
            if (s_allAssets[i] == asset) {
                isAdded = true;
                break;
            }
        }

        if (!isAdded) {
            s_allAssets.push(asset);
        }

        emit AssetAdded(asset, minimumBudget);
    }

    /**
     * @notice Remove support for an asset
     * @param asset The address of the asset to remove support for
     * @dev Cannot remove core assets like NATIVE_TOKEN
     */
    function removeAssetSupport(address asset) external onlyOwner {
        if (!s_supportedAssets[asset]) {
            revert AssetNotSupported();
        }

        if (asset == NATIVE_TOKEN) {
            revert CannotRemoveCoreAssets();
        }

        s_supportedAssets[asset] = false;
        delete s_minimumTotalBudget[asset];

        emit AssetRemoved(asset);
    }

    /**
     * @notice Update minimum requirements for an asset
     * @param asset The address of the asset to update
     * @param minimumBudget The new minimum budget for the asset
     * @dev The asset must be supported, and the minimum fee and budget must be greater than zero
     */
    function updateAssetRequirements(address asset, uint256 minimumBudget) external onlyOwner {
        if (!s_supportedAssets[asset]) {
            revert AssetNotSupported();
        }

        if (minimumBudget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }

        s_minimumTotalBudget[asset] = minimumBudget;

        emit AssetUpdated(asset, minimumBudget);
    }

    /**
     * @notice Checks if an asset is supported
     * @param asset The address of the asset to check
     * @return bool indicating if the asset is supported
     */
    function isAssetSupported(address asset) external view returns (bool) {
        return s_supportedAssets[asset];
    }

    /**
     * @notice Gets the minimum budget for a specific asset
     * @param asset The address of the asset
     * @return The minimum budget required for the specified asset
     */
    function getMinimumBudget(address asset) external view returns (uint256) {
        return s_minimumTotalBudget[asset];
    }

    /**
     * @notice Gets the fee balance for a specific asset
     * @param asset The address of the asset
     * @return The current fee balance for the specified asset
     */
    function getFeeBalance(address asset) external view returns (uint256) {
        return s_feeBalances[asset];
    }

    /**
     * @notice Gets the total balance of the contract for a specific asset
     * @param asset The address of the asset
     * @return The total balance of the contract for the specified asset
     */
    function getTotalBalance(address asset) external view returns (uint256) {
        if (asset == NATIVE_TOKEN) {
            return address(this).balance;
        }
        return IERC20(asset).balanceOf(address(this));
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
    function getAllAssets() external view returns (address[] memory) {
        return s_allAssets;
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

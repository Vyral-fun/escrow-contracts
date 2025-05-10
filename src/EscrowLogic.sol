// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";

contract EscrowLogic is Initializable, OwnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address private BASE_UNISWAP_V2_FACTORY;
    address private BASE_UNISWAP_V2_ROUTER;
    uint256 private s_yapRequestCount;
    uint256 private s_feeBalance;
    address private kaitoTokenAddress;
    address private usdcTokenAddress;
    address private usdtTokenAddress;
    mapping(uint256 => YapRequest) private s_yapRequests;
    mapping(uint256 => address[]) private s_yap_winners;
    mapping(address => bool) private s_is_admin;
    mapping(uint256 => mapping(address => ApprovedWinner)) private s_yapWinnersApprovals; // yapId => (winner => ApprovedWinner)

    enum YapTokenType {
        Kaito,
        USDC,
        USDT
    }

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
    event RewardsDistributed(uint256 indexed yapRequestId, address[] winners, uint256 totalReward);

    error OnlyAdminsCanDistributeRewards();
    error NoWinnersProvided();
    error FeeMustBeGreaterThanZero();
    error InvalidFeePercentage();
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
        address _usdcTokenAddress,
        address _usdtTokenAddress,
        address _kaitoAddress,
        address _uniswapFactory,
        address _uniswapRouter,
        address[] memory _admins,
        uint256 _currentYapRequestCount
    ) public initializer {
        __Ownable_init(msg.sender);

        if (kaitoTokenAddress != address(0)) {
            revert AlreadyInitialized();
        }

        s_yapRequestCount = _currentYapRequestCount;
        s_is_admin[msg.sender] = true;
        s_feeBalance = 0;
        kaitoTokenAddress = _kaitoAddress;
        usdcTokenAddress = _usdcTokenAddress;
        usdtTokenAddress = _usdtTokenAddress;
        BASE_UNISWAP_V2_FACTORY = _uniswapFactory;
        BASE_UNISWAP_V2_ROUTER = _uniswapRouter;

        for (uint256 i = 0; i < _admins.length; i++) {
            s_is_admin[_admins[i]] = true;
        }

        emit Initialized(_kaitoAddress, _admins);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @notice Creates a new yap request with specified a budget
     * @param _budget The budget for the yap request
     * @param _feePercentage The percentage for fee from the yap budget (1% = 1000, 0.75% = 750)
     * @dev The fee must be greater than zero
     * @dev The budget must be greater than zero
     * @return The ID of the new yap request
     */
    function createRequest(uint256 _budget, uint256 _feePercentage, YapTokenType paymentToken)
        external
        returns (uint256, uint256)
    {
        if (_budget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        if (_feePercentage == 0) {
            revert FeeMustBeGreaterThanZero();
        }

        uint256 exactBudget;

        if (paymentToken == YapTokenType.Kaito) {
            IERC20(kaitoTokenAddress).safeTransferFrom(msg.sender, address(this), _budget);

            (uint256 _exactBudget, uint256 _fee) = calculateFee(_budget, _feePercentage);
            s_feeBalance += _fee;
            exactBudget = _exactBudget;
        } else {
            address stableToken = paymentToken == YapTokenType.USDC ? usdcTokenAddress : usdtTokenAddress;
            if (stableToken == address(0)) {
                revert InvalidERC20Address();
            }
            IERC20(stableToken).safeTransferFrom(msg.sender, address(this), _budget);
            IERC20(stableToken).approve(address(BASE_UNISWAP_V2_ROUTER), _budget);

            address[] memory path = new address[](2);
            IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(BASE_UNISWAP_V2_ROUTER);
            path[0] = stableToken;
            path[1] = kaitoTokenAddress;

            uint256[] memory expectedAmounts = uniswapRouter.getAmountsOut(_budget, path);
            uint256 expectedKaitoAmount = expectedAmounts[1];
            uint256 minKaitoAmount = (expectedKaitoAmount * 995) / 1000; // 0.5% slippage

            uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
                _budget,
                minKaitoAmount,
                path,
                address(this),
                block.timestamp + 300 // 5 minutes
            );

            uint256 receivedKaito = amounts[amounts.length - 1];

            (uint256 _exactBudget, uint256 _fee) = calculateFee(receivedKaito, _feePercentage);

            s_feeBalance += _fee;
            exactBudget = _exactBudget;
        }

        s_yapRequestCount += 1;
        s_yapRequests[s_yapRequestCount] =
            YapRequest({yapId: s_yapRequestCount, creator: msg.sender, budget: exactBudget, isActive: true});

        emit YapRequestCreated(s_yapRequestCount, msg.sender, exactBudget);

        return (s_yapRequestCount, exactBudget);
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
            s_yap_winners[yapRequestId].push(winners[i]);
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

        uint256 usdcBalance = IERC20(usdcTokenAddress).balanceOf(address(this));
        uint256 usdtBalance = IERC20(usdtTokenAddress).balanceOf(address(this));

        if (usdcBalance > 0) {
            IERC20(usdcTokenAddress).safeTransfer(to, usdcBalance);
        }

        if (usdtBalance > 0) {
            IERC20(usdtTokenAddress).safeTransfer(to, usdtBalance);
        }
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
     * @notice Resets the usdt token address
     * @param usdt The new token address
     */
    function resetUsdtAddress(address usdt) public onlyOwner {
        if (usdt == address(0)) {
            revert InvalidERC20Address();
        }
        usdtTokenAddress = usdt;
    }

    /**
     * @notice Resets the usdc token address
     * @param usdc The new token address
     */
    function resetUsdcAddress(address usdc) public onlyOwner {
        if (usdc == address(0)) {
            revert InvalidERC20Address();
        }
        usdcTokenAddress = usdc;
    }

    /**
     * @notice Gets the fee balance
     * @return The current fee balance
     */
    function getFeeBalance() external view returns (uint256, uint256, uint256) {
        uint256 usdcBalance = IERC20(usdcTokenAddress).balanceOf(address(this));
        uint256 usdtBalance = IERC20(usdtTokenAddress).balanceOf(address(this));
        return (s_feeBalance, usdtBalance, usdcBalance);
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
     * @notice Gets the address of the Usdt token
     * @return The address of the Usdt token
     */
    function getUsdtAddress() external view returns (address) {
        return usdtTokenAddress;
    }

    /**
     * @notice Gets the address of the Usdc token
     * @return The address of the Usdc token
     */
    function getUsdcAddress() external view returns (address) {
        return usdcTokenAddress;
    }

    /**
     * @notice Gets the address of the pair
     * @param tokenAddress The address of the stable token
     * @return The address of the pair
     */
    function getPairDetails(address tokenAddress) external view returns (address) {
        IUniswapV2Factory factory = IUniswapV2Factory(BASE_UNISWAP_V2_FACTORY);
        address pairAddress = factory.getPair(tokenAddress, kaitoTokenAddress);
        return pairAddress;
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

    function calculateFee(uint256 _budget, uint256 _feePercentage) internal pure returns (uint256, uint256) {
        if (_feePercentage == 0) {
            revert FeeMustBeGreaterThanZero();
        }
        if (_budget == 0) {
            revert BudgetMustBeGreaterThanZero();
        }
        uint256 fee = (_budget * _feePercentage) / 100000;
        uint256 exactBudget = _budget - fee;
        return (exactBudget, fee);
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Router02 is IUniswapV2Router02 {
    IUniswapV2Factory public factoryInstance;
    uint256 private mockLiquidity = 10000 ether;

    constructor(address _factory) {
        factoryInstance = IUniswapV2Factory(_factory);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        require(path.length >= 2, "INVALID_PATH");
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(deadline >= block.timestamp, "EXPIRED");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 1; i < path.length; i++) {
            amounts[i] = (amounts[i - 1] * 98) / 100;

            IERC20(path[i]).transfer(to, amounts[i]);
        }

        return amounts;
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 1; i < path.length; i++) {
            amounts[i] = (amounts[i - 1] * 98) / 100;
        }

        return amounts;
    }

    function WETH() external pure override returns (address) {
        return address(0);
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        override
        returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = (amounts[i] * 102) / 100;
        }

        return amounts;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        return (amountADesired, amountBDesired, mockLiquidity);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable override returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        return (amountTokenDesired, msg.value, mockLiquidity);
    }

    function factory() external pure override returns (address) {
        return address(0);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountIn)
    {
        return (amountOut * reserveIn) / reserveOut;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return (amountIn * reserveOut) / reserveIn;
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        external
        pure
        override
        returns (uint256 amountB)
    {
        return (amountA * reserveB) / reserveA;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountA, uint256 amountB) {
        return (amountAMin, amountBMin);
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        return (amountTokenMin, amountETHMin);
    }

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountETH) {
        return amountETHMin;
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        return (amountTokenMin, amountETHMin);
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountETH) {
        return amountETHMin;
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountA, uint256 amountB) {
        return (amountAMin, amountBMin);
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        return amounts;
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        amounts[0] = msg.value;
        return amounts;
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable override {}

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        return amounts;
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override {}

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override {}

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        return amounts;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        return amounts;
    }
}

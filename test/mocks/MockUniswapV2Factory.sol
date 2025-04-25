// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@uniswap/v2-core/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUniswapV2Factory is IUniswapV2Factory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");

        if (pairs[token0][token1] != address(0)) {
            return pairs[token0][token1];
        }

        pair = address(uint160(uint256(keccak256(abi.encodePacked(token0, token1, block.timestamp)))));
        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;

        allPairs.push(pair);

        return pair;
    }

    function getPair(address tokenA, address tokenB) external view override returns (address) {
        return pairs[tokenA][tokenB];
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function feeTo() external view override returns (address) {
        return address(0);
    }

    function feeToSetter() external view override returns (address) {
        return address(0);
    }

    function setFeeTo(address) external override {}

    function setFeeToSetter(address) external override {}
}

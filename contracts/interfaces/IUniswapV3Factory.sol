// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IUniswapV3Factory {
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISmartVaultManager {
    function protocol() external returns (address);

    function feeRate() external returns (uint256);

    function collateralRate() external returns (uint256);

    function clEurUsd() external returns (address);

    function clEthUsd() external returns (address);
}
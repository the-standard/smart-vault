// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISmartVaultManager {
    function protocol() external view returns (address);

    function feeRate() external view returns (uint256);

    function collateralRate() external view returns (uint256);

    function clEurUsd() external view returns (address);

    function clEthUsd() external view returns (address);
}
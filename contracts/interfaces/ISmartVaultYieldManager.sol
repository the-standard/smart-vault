// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISmartVaultYieldManager {
    function depositYield(bytes32 _symbol) external payable;
}
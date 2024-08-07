// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISmartVaultYieldManager {
    function depositYield(address _collateralToken, uint256 _euroPercentage) external payable returns (address vault0, address vault1);
}
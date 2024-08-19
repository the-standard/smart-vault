// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISmartVaultYieldManager {
    function depositYield(address _collateralToken, uint256 _euroPercentage) external returns (address vault0, address vault1);
    function withdrawYield(address _vault, address _token) external;
}
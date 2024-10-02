// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface ISmartVaultYieldManager {
    function deposit(address _collateralToken, uint256 _usdPercentage)
        external
        returns (address vault0, address vault1);
    function withdraw(address _vault, address _token) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface ISmartVaultYieldManager {
    function getHypervisorForCollateral(address _collateralToken) external returns (address _hypervisor);
    function deposit(address _collateralToken, uint256 _usdPercentage)
        external
        returns (address vault0, address vault1);
    function withdraw(address _hypervisor, address _token) external;
    function quickDeposit(address _token, uint256 _deposit) external;
    function quickWithdraw(address _hypervisor, address _token) external returns (uint256 _withdrawn);
}

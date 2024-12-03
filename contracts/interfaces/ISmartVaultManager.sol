// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "contracts/interfaces/ISmartVault.sol";

interface ISmartVaultManager {
    struct SmartVaultData {
        uint256 tokenId;
        uint256 collateralRate;
        uint256 mintFeeRate;
        uint256 burnFeeRate;
        ISmartVault.Status status;
    }

    function HUNDRED_PC() external view returns (uint256);
    function tokenManager() external view returns (address);
    function protocol() external view returns (address);
    function burnFeeRate() external view returns (uint256);
    function mintFeeRate() external view returns (uint256);
    function collateralRate() external view returns (uint256);
    function weth() external view returns (address);
    function swapRouter() external view returns (address);
    function swapFeeRate() external view returns (uint256);
    function yieldManager() external view returns (address);
    function vaultAutoRedemption(
        address _smartVault,
        address _collateralAddr,
        bytes memory _swapPath,
        uint256 _collateralAmount
    ) external returns (uint256 _amountOut);
    function vaultData(uint256 _tokenID) external view returns (SmartVaultData memory);
}

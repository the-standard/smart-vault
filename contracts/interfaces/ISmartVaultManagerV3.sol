// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ISmartVaultManagerV2.sol";

interface ISmartVaultManagerV3 is ISmartVaultManagerV2, ISmartVaultManager {
    function yieldManager() external view returns (address);
    function vaultAutoRedemption(
        address _smartVault,
        address _collateralAddr,
        bytes memory _swapPath,
        uint256 _collateralAmount
    ) external returns (uint256 _amountOut);
}

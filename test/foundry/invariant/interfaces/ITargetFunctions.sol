// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ITargetFunctions {
    function helper_addSmartVaultCollateral(uint256 symbolIndex) external;
    function smartVaultManagerV6_liquidateVault(uint256 tokenId) external;
    function smartVaultV4_burn(uint256 amount) external;
    function smartVaultV4_depositYield(uint256 symbolIndex, uint256 stablePercentage) external;
    function smartVaultV4_mint(address to, uint256 amount) external;
    function smartVaultV4_removeAsset(bool removeCollateral, uint256 symbolIndex, uint256 amount, address to)
        external;
    function smartVaultV4_removeCollateral(uint256 symbolIndex, uint256 amount, address to) external;
    function smartVaultV4_removeCollateralNative(uint256 amount, address payable to) external;
    function smartVaultV4_swap(uint256 inTokenIndex, uint256 outTokenIndex, uint256 amount, uint256 requestedMinOut)
        external;
    function smartVaultV4_withdrawYield(uint256 hypervisorIndex, uint256 symbolIndex) external;
}

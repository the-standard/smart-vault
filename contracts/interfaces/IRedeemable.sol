// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IRedeemable {
    function autoRedemption(
        address _swapRouterAddress,
        address _quoterAddress,
        address _collateralToken,
        bytes memory _swapPath,
        uint256 _USDCTargetAmount,
        address _hypervisor
    ) external returns (uint256 _redeemed);
}

interface IRedeemableLegacy {
    function autoRedemption(
        address _swapRouterAddress,
        address _collateralAddr,
        bytes memory _swapPath,
        uint256 _amountIn
    ) external returns (uint256 _redeemed);
}

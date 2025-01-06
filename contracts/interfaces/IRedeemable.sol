// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IRedeemable {
    function autoRedemption(
        address _swapRouterAddress,
        address _quoterAddress,
        address _collateralToken,
        uint256 _USDsTargetAmount,
        bytes memory _swapPathInput,
        bytes memory _swapPathOutput,
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

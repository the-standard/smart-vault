// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IUniProxy {
    function getDepositAmount(address pos, address token, uint256 _deposit)
        external
        view
        returns (uint256 amountStart, uint256 amountEnd);
    function deposit(uint256 deposit0, uint256 deposit1, address to, address pos, uint256[4] memory minIn)
        external
        returns (uint256 shares);
}

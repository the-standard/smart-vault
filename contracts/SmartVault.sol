// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract SmartVault {
    uint256 public collateral;
    uint256 public minted;

    function addCollateralETH() external payable {
        collateral += msg.value;
    }
}

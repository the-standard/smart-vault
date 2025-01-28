// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IRewardGateway {
    function liquidateVault(uint256 _tokenID) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ITokenManager.sol";

interface IPriceCalculator {
    function tokenToUSD(ITokenManager.Token memory _token, uint256 _amount) external view returns (uint256);
    function USDToToken(ITokenManager.Token memory _token, uint256 _amount) external view returns (uint256);
}
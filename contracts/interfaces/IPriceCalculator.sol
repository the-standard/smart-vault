// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IChainlink.sol";

interface IPriceCalculator {
    function avgPrice(uint8 _hours, IChainlink _priceFeed) external view returns (uint256);
}
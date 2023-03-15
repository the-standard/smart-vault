// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IPriceCalculator.sol";

contract PriceCalculator is IPriceCalculator {
    function avgPrice(uint8 _hours, IChainlink _priceFeed) external view returns (uint256) {
        return uint256(_priceFeed.latestAnswer());
    }
}
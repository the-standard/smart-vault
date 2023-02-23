// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IChainlink.sol";

contract ChainlinkMock is IChainlink {
    int256 private price;

    constructor(int256 _price) {
        price = _price;
    }

    function latestAnswer() external view returns(int256) {
        return price;
    }

    function decimals() external pure returns (uint8) { return 8; }

    function setPrice(int256 _price) external {
        price = _price;
    }
}

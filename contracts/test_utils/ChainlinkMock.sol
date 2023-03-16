// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IChainlink.sol";

contract ChainlinkMock is IChainlink {
    int256 private price;

    constructor(int256 _price) {
        price = _price;
    }

    function decimals() external pure returns (uint8) { return 8; }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function getRoundData(uint80 _roundId) external view 
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
            return(0, price, 0, block.timestamp - 4 hours, 0);
        }

    function latestRoundData() external view 
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
            return(0, price, 0, block.timestamp - 4 hours, 0);
        }
}

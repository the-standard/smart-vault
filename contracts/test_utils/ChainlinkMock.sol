// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkMock is AggregatorV3Interface {
    string private desc;
    int256 private price;

    struct PriceRound {
        uint256 timestamp;
        int256 price;
    }

    constructor(string memory _desc) {
        desc = _desc;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function latestRoundData() external view returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = price;
    }

    function getRoundData(uint80 _roundId) external view returns (uint80, int256 answer, uint256, uint256, uint80) {
        answer = price;
    }

    function description() external view returns (string memory) {
        return desc;
    }

    function version() external view returns (uint256) {
        return 1;
    }
}

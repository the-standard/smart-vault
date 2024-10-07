// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ChainlinkMock is AggregatorV3Interface {
    string private desc;
    int256 private price;
    uint256 private updatedAt;
    uint256 private startedAt;
    uint80 private roundID;

    struct PriceRound {
        uint256 timestamp;
        int256 price;
    }

    constructor(string memory _desc) {
        desc = _desc;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        roundID = 1;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function setRoundID(uint80 _roundID) external {
        roundID = _roundID;
    }

    function setStartedAt(uint256 _startedAt) external {
        startedAt = _startedAt;
    }

    function latestRoundData()
        external
        view
        returns (uint80 _roundID, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80)
    {
        _roundID = roundID;
        _answer = price;
        _startedAt = startedAt;
        _updatedAt = updatedAt;
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

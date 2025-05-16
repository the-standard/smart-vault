// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol" as Chainlink;
import {console} from "forge-std/Test.sol";

contract CombinedDataFeed is Chainlink.AggregatorV3Interface {
    uint256 private constant TIMEOUT = 1 days;
    Chainlink.AggregatorV3Interface public immutable feedA;
    Chainlink.AggregatorV3Interface public immutable feedB;
    
    error InvalidRoundId();
    error InvalidPrice();
    error InvalidUpdate();
    error StalePrice();

    constructor(address _feedA, address _feedB) {
        feedA = Chainlink.AggregatorV3Interface(_feedA);
        feedB = Chainlink.AggregatorV3Interface(_feedB);
    }

    function decimals() external view returns (uint8) {
        return 8;
    }

    function description() external view returns (string memory) {
        return string.concat(feedA.description(), " / ", feedB.description());
    }

    function version() external view returns (uint256) {
        return 0;
    }

    function validateLatestData(Chainlink.AggregatorV3Interface _feed) private view returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound) = _feed.latestRoundData();
        if (_roundId == 0) revert InvalidRoundId();
        if (_answer == 0) revert InvalidPrice();
        if (_updatedAt == 0 || _updatedAt > block.timestamp) revert InvalidUpdate();
        if (block.timestamp - _updatedAt > TIMEOUT) revert StalePrice();
        return (_roundId, _answer, _startedAt, _updatedAt, _answeredInRound);
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = latestRoundData();
    }

    function latestRoundData()
        public
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (uint80 roundIdA, int256 answerA, uint256 startAtA, uint256 updatedAtA, uint80 answeredInRoundA) = validateLatestData(feedA);
        (uint80 roundIdB, int256 answerB, uint256 startAtB, uint256 updatedAtB, uint80 answeredInRoundB) = validateLatestData(feedB);
        roundId = roundIdB;
        startedAt = startAtB;
        updatedAt = updatedAtB;
        answer = answerA * answerB * 1e8 / int256(10 ** feedA.decimals()) / int256(10 ** feedB.decimals());
        answeredInRound = answeredInRoundB;
    }
}

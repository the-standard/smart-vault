// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IChainlink.sol";

contract ChainlinkMockV2 is IChainlink {
    PriceRound[] public prices;

    struct PriceRound { uint256 timestamp; int256 price; }

    function decimals() external pure returns (uint8) { return 8; }

    function addPriceRound(uint256 timestamp, int256 price) external {
        prices.push(PriceRound(timestamp, price));
    }

    // TODO actually make this work like it should (and stub the price as this price)
    function setPrice(int256 _price) external {
        prices.push(PriceRound(block.timestamp - 4 hours, _price));
    }

    function getRoundData(uint80 _roundId) external view 
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
            roundId = _roundId;
            answer = prices[roundId].price;
            updatedAt = prices[roundId].timestamp;
        }

    function latestRoundData() external view 
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
            roundId = uint80(prices.length - 1);
            answer = prices[roundId].price;
            updatedAt = prices[roundId].timestamp;
        }
}

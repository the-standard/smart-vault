// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IChainlink.sol";
import "contracts/interfaces/IPriceCalculator.sol";

contract PriceCalculator is IPriceCalculator {
    bytes32 private constant ETH = bytes32("ETH");

    IChainlink public clEurUsd;

    constructor (address _clEurUsd) {
        clEurUsd = IChainlink(_clEurUsd);
    }

    function avgPrice(uint8 _hours, IChainlink _priceFeed) private view returns (uint256) {
        uint256 fourHoursAgo = block.timestamp - _hours * 1 hours;
        uint256 roundTS;
        uint80 roundId;
        int256 answer;
        (roundId, answer,, roundTS,) = _priceFeed.latestRoundData();
        uint256 accummulatedRoundPrices = uint256(answer);
        uint256 roundCount = 1;
        while (roundTS > fourHoursAgo) {
            roundCount++;
            roundId--;
            (, answer,, roundTS,) = _priceFeed.getRoundData(roundId);
            accummulatedRoundPrices += uint256(answer);
        }
        return accummulatedRoundPrices / roundCount;
    }

    function getTokenScaleDiff(bytes32 _symbol, address _tokenAddress) private view returns (uint256 scaleDiff) {
        return _symbol == ETH ? 0 : 18 - ERC20(_tokenAddress).decimals();
    }

    function tokenToEur(ITokenManager.Token memory _token, uint256 _amount) external view returns (uint256) {
        IChainlink tokenUsdClFeed = IChainlink(_token.clAddr);
        uint256 clScaleDiff = clEurUsd.decimals() - tokenUsdClFeed.decimals();
        uint256 scaledCollateral = _amount * 10 ** getTokenScaleDiff(_token.symbol, _token.addr);
        uint256 collateralUsd = scaledCollateral * 10 ** clScaleDiff * avgPrice(4, tokenUsdClFeed);
        return collateralUsd / avgPrice(4, clEurUsd);
    }
}
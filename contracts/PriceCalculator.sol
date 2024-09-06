// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol" as Chainlink;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IPriceCalculator.sol";

contract PriceCalculator is IPriceCalculator {
    bytes32 private immutable NATIVE;

    constructor (bytes32 _native) {
        NATIVE = _native;
    }

    function getTokenScaleDiff(bytes32 _symbol, address _tokenAddress) private view returns (uint256 scaleDiff) {
        return _symbol == NATIVE ? 0 : 18 - ERC20(_tokenAddress).decimals();
    }

    function tokenToUSD(ITokenManager.Token memory _token, uint256 _tokenValue) external view returns (uint256) {
        Chainlink.AggregatorV3Interface tokenUsdClFeed = Chainlink.AggregatorV3Interface(_token.clAddr);
        uint256 scaledCollateral = _tokenValue * 10 ** getTokenScaleDiff(_token.symbol, _token.addr);
        (,int256 _tokenUsdPrice,,,) = tokenUsdClFeed.latestRoundData();
        return scaledCollateral * uint256(_tokenUsdPrice) / 10 ** _token.clDec;
    }
}
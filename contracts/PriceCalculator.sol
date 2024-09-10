// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol" as Chainlink;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IPriceCalculator.sol";

import "hardhat/console.sol";

contract PriceCalculator is IPriceCalculator {
    uint256 private constant TIMEOUT = 24 hours;
    bytes32 private immutable NATIVE;
    address private USDCToUSDAddr;

    error InvalidRoundId();
    error InvalidPrice();
    error InvalidUpdate();
    error StalePrice();

    constructor (bytes32 _native, address _USDCToUSDAddr) {
        NATIVE = _native;
        USDCToUSDAddr = _USDCToUSDAddr;
    }

    function getTokenScaleDiff(bytes32 _symbol, address _tokenAddress) private view returns (uint256 scaleDiff) {
        return _symbol == NATIVE ? 0 : 18 - ERC20(_tokenAddress).decimals();
    }

    function validateData(uint80 _roundId, int256 _answer, uint256 _updatedAt) private view {
        if(_roundId == 0) revert InvalidRoundId();
        if(_answer == 0) revert InvalidPrice();
        if(_updatedAt == 0 || _updatedAt > block.timestamp) revert InvalidUpdate();
        if(block.timestamp - _updatedAt > TIMEOUT) revert StalePrice();
    }

    function tokenToUSD(ITokenManager.Token memory _token, uint256 _tokenValue) external view returns (uint256) {
        Chainlink.AggregatorV3Interface tokenUsdClFeed = Chainlink.AggregatorV3Interface(_token.clAddr);
        uint256 scaledCollateral = _tokenValue * 10 ** getTokenScaleDiff(_token.symbol, _token.addr);
        (uint80 _roundId, int256 _tokenUsdPrice, , uint256 _updatedAt, ) = tokenUsdClFeed.latestRoundData();
        validateData(_roundId, _tokenUsdPrice, _updatedAt);
        return scaledCollateral * uint256(_tokenUsdPrice) / 10 ** _token.clDec;
    }

    function USDCToUSD(uint256 _amount, uint8 _dec) external view returns (uint256) {
        Chainlink.AggregatorV3Interface _clUSDCToUSD = Chainlink.AggregatorV3Interface(USDCToUSDAddr);
        (uint80 _roundId, int256 _USDCToUSDPrice, , uint256 _updatedAt, ) = _clUSDCToUSD.latestRoundData();
        validateData(_roundId, _USDCToUSDPrice, _updatedAt);
        return _amount * uint256(_USDCToUSDPrice) * 10 ** (18 - _dec) / 1e8;
    }
}
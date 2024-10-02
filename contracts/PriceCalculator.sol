// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol" as Chainlink;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/interfaces/IPriceCalculator.sol";

contract PriceCalculator is IPriceCalculator, Ownable {
    uint256 private constant DEFAULT_TIMEOUT = 1 days;
    bytes32 private immutable NATIVE;
    address private USDCToUSDAddr;
    Chainlink.AggregatorV3Interface private sequencerUptimeFeed;
    mapping(address => uint256) private dataFeedTimeouts;

    error InvalidRoundId();
    error InvalidPrice();
    error InvalidUpdate();
    error StalePrice();
    error SequencerDown();
    error GracePeriodNotOver();

    constructor (bytes32 _native, address _USDCToUSDAddr, address _sequencerUptimeFeed) {
        NATIVE = _native;
        USDCToUSDAddr = _USDCToUSDAddr;
        sequencerUptimeFeed = Chainlink.AggregatorV3Interface(_sequencerUptimeFeed);
    }

    function validateSequencerUp() private view {
        (,int256 answer,uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= 1 hours) {
            revert GracePeriodNotOver();
        }
    }

    function overscaledCollateral(ITokenManager.Token memory _token, uint256 _tokenValue) private view returns (uint256 _scaledValue) {
        uint8 _dec = _token.symbol == NATIVE ? 18 : ERC20(_token.addr).decimals();
        return _tokenValue * 10 ** (36 - _dec);
    }

    function getTimeout(address _dataFeed) private view returns (uint256 _timeout) {
        _timeout = dataFeedTimeouts[_dataFeed];
        return _timeout > 0 ? _timeout : DEFAULT_TIMEOUT;
    }

    function validateData(uint80 _roundId, int256 _answer, uint256 _updatedAt, address _dataFeed) private view {
        validateSequencerUp();
        if(_roundId == 0) revert InvalidRoundId();
        if(_answer == 0) revert InvalidPrice();
        if(_updatedAt == 0 || _updatedAt > block.timestamp) revert InvalidUpdate();
        if(block.timestamp - _updatedAt > getTimeout(_dataFeed)) revert StalePrice();
    }

    function tokenToUSD(ITokenManager.Token memory _token, uint256 _tokenValue) external view returns (uint256) {
        Chainlink.AggregatorV3Interface tokenUsdClFeed = Chainlink.AggregatorV3Interface(_token.clAddr);
        (uint80 _roundId, int256 _tokenUsdPrice, , uint256 _updatedAt, ) = tokenUsdClFeed.latestRoundData();
        validateData(_roundId, _tokenUsdPrice, _updatedAt, _token.clAddr);
        return overscaledCollateral(_token, _tokenValue) * uint256(_tokenUsdPrice) / 10 ** _token.clDec / 1e18;
    }

    function USDCToUSD(uint256 _amount, uint8 _dec) external view returns (uint256) {
        Chainlink.AggregatorV3Interface _clUSDCToUSD = Chainlink.AggregatorV3Interface(USDCToUSDAddr);
        (uint80 _roundId, int256 _USDCToUSDPrice, , uint256 _updatedAt, ) = _clUSDCToUSD.latestRoundData();
        validateData(_roundId, _USDCToUSDPrice, _updatedAt, USDCToUSDAddr);
        return _amount * uint256(_USDCToUSDPrice) * 10 ** (18 - _dec) / 10 ** _clUSDCToUSD.decimals();
    }

    function setDataFeedTimeout(address _dataFeed, uint256 _timeout) external onlyOwner {
        dataFeedTimeouts[_dataFeed] = _timeout;
    }
}

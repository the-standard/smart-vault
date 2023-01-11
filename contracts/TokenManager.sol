// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/IChainlink.sol";

contract TokenManager is Ownable {
    bytes32 private constant ETH = bytes32("ETH");

    Token[] private acceptedTokens;
    IChainlink public clEthUsd;
    IChainlink public clEurUsd;

    struct Token { bytes32 symbol; address addr; uint8 dec; address clAddr; uint8 clDec; }

    constructor(address _clEthUsd, address _clEurUsd) {
        clEthUsd = IChainlink(_clEthUsd);
        clEurUsd = IChainlink(_clEurUsd);
        acceptedTokens.push(Token(ETH, address(0), 18, _clEthUsd, clEthUsd.decimals()));
    }

    function getAcceptedTokens() external view returns (Token[] memory) {
        return acceptedTokens;
    }

    function addAcceptedToken(address _token, address _chainlinkFeed) external onlyOwner {
        ERC20 token = ERC20(_token);
        bytes32 symbol = bytes32(bytes(token.symbol()));
        for (uint256 i = 0; i < acceptedTokens.length; i++) if (acceptedTokens[i].symbol == symbol) revert("err-token-exists");
        IChainlink dataFeed = IChainlink(_chainlinkFeed);
        acceptedTokens.push(Token(symbol, _token, token.decimals(), _chainlinkFeed, dataFeed.decimals()));
    }

    function removeAcceptedToken(bytes32 _symbol) external onlyOwner {
        require(_symbol != ETH);
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (acceptedTokens[i].symbol == _symbol) {
                acceptedTokens[i] = acceptedTokens[acceptedTokens.length - 1];
                acceptedTokens.pop();
            }
        }
    }
}

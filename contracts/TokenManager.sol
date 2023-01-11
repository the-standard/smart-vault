// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/IChainlink.sol";

contract TokenManager is Ownable {

    Token[] private acceptedTokens;

    struct Token { bytes32 symbol; address addr; uint8 dec; address clAddr; uint8 clDec; }

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

    function removeAcceptedToken(string memory _symbol) external onlyOwner {
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (acceptedTokens[i].symbol == bytes32(bytes(_symbol))) {
                acceptedTokens[i] = acceptedTokens[acceptedTokens.length - 1];
                acceptedTokens.pop();
            }
        }
    }
}

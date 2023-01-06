// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/interfaces/IChainlink.sol";

contract TokenManager is Ownable {

    Token[] private acceptedTokens;

    struct Token { string symbol; address addr; string name; uint8 dec; address clAddr; uint8 clDec; }

    function getAcceptedTokens() external view returns (Token[] memory) {
        return acceptedTokens;
    }

    function addAcceptedToken(address _token, address _chainlinkFeed) external onlyOwner {
        ERC20 token = ERC20(_token);
        for (uint256 i = 0; i < acceptedTokens.length; i++) if (eqlStrings(acceptedTokens[i].symbol, token.symbol())) revert("err-token-exists");
        IChainlink dataFeed = IChainlink(_chainlinkFeed);
        acceptedTokens.push(Token(token.symbol(), _token, token.name(), token.decimals(), _chainlinkFeed, dataFeed.decimals()));
    }

    function removeAcceptedToken(string memory _symbol) external onlyOwner {
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if(eqlStrings(acceptedTokens[i].symbol, _symbol)) {
                acceptedTokens[i] = acceptedTokens[acceptedTokens.length - 1];
                acceptedTokens.pop();
            }
        }
    }

    function eqlStrings(string memory _a, string memory _b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((_a))) == keccak256(abi.encodePacked((_b))));
    }
}

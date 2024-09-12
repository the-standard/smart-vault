// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {Bounds} from "./Bounds.sol";
import {Setup} from "./Setup.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";

// import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Helper is Asserts, Bounds, Setup {
    address internal msgSender;

    modifier getMsgSender() virtual {
        msgSender = msg.sender;
        _;
    }

    function _getRandomUser(address user) internal returns (address) {
        return users[between(uint256(uint160(user)), 0, users.length)];
    }

    function _getRandomSmartVault(uint256 tokenId) internal returns (SmartVaultV4, uint256) {
        return (SmartVaultV4(_tokenIdToSmartVault(tokenId)), tokenId = _getRandomTokenId(tokenId));
    }

    function _getRandomTokenId(uint256 tokenId) internal returns (uint256) {
        return between(tokenId, 0, vaultManager.totalSupply());
    }

    function _tokenIdToSmartVault(uint256 tokenId) internal returns (SmartVaultV4) {
        return SmartVaultV4(smartVaultIndex.getVaultAddress(tokenId));
    }

    function _getRandomCollateral(uint256 symbolIndex) internal returns (ERC20Mock, bytes32) {
        bytes32 symbol = _getRandomSymbol(symbolIndex);
        return (_symbolToAddress(symbol), symbol);
    }

    function _getRandomSymbol(uint256 symbolIndex) internal returns (bytes32) {
        return collateralSymbols[between(symbolIndex, 0, symbols.length)];
    }

    function _symbolToAddress(bytes32 symbol) internal returns (ERC20Mock) {
        return collateralData[symbol].token
    }
}

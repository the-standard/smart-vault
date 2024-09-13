// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {Bounds} from "./Bounds.sol";
import {Setup} from "./Setup.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Helper is Asserts, Bounds, Setup {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal msgSender;
    EnumerableSet.AddressSet internal hypervisors;

    modifier getMsgSender() virtual {
        msgSender = msg.sender;
        _;
    }

    function _getRandomUser(address user) internal returns (address) {
        return users[between(uint256(uint160(user)), 0, users.length)];
    }

    // NOTE: not needed when using a single SmartVault
    // function _getRandomSmartVault(uint256 tokenId) internal returns (SmartVaultV4, uint256) {
    //     return (SmartVaultV4(_tokenIdToSmartVault(tokenId)), tokenId = _getRandomTokenId(tokenId));
    // }

    // function _getRandomTokenId(uint256 tokenId) internal returns (uint256) {
    //     return between(tokenId, 0, smartVaultManager.totalSupply());
    // }

    // function _tokenIdToSmartVault(uint256 tokenId) internal returns (SmartVaultV4) {
    //     return SmartVaultV4(smartVaultIndex.getVaultAddress(tokenId));
    // }

    function _getRandomCollateral(uint256 symbolIndex) internal returns (ERC20Mock, bytes32) {
        bytes32 symbol = _getRandomSymbol(symbolIndex);
        return (_symbolToToken(symbol), symbol);
    }

    function _getRandomSymbol(uint256 symbolIndex) internal returns (bytes32) {
        return collateralSymbols[between(symbolIndex, 0, collateralSymbols.length)];
    }

    function _symbolToToken(bytes32 symbol) internal returns (ERC20Mock) {
        return collateralData[symbol].token;
    }

    function _getRandomHypervisor(uint256 hypervisorIndex) internal returns (address) {
        if (hypervisors.length() == 0) return address(0);

        return hypervisors.at(between(hypervisorIndex, 0, hypervisors.length()));
    }

    function _addHypervisor(address hypervisor) internal {
        hypervisors.add(hypervisor);
    }

    function _removeHypervisor(address hypervisor) internal {
        hypervisors.remove(hypervisor);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";
import {Bounds} from "./Bounds.sol";
import {Setup} from "./Setup.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";

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

    function _getRandomSmartVault() internal returns (SmartVaultV4) {
        return smartVaults[VAULT_OWNER][0].vault; // TODO: randomize vaults
    }
}

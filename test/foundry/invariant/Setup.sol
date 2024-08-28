// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import {PropertiesConstants} from "@crytic/util/PropertiesConstants.sol";
import {vm} from "@chimera/Hevm.sol";

import {SmartVaultFixture} from "../fixtures/SmartVaultFixture.sol";

abstract contract Setup is BaseSetup, PropertiesConstants, SmartVaultFixture {
    address[] internal users;

    function setup() internal virtual override {
        super.setUp();

        // set up users that will be used to call target functions
        users.push(USER1);
        users.push(USER2);
        users.push(USER3);
        users.push(VAULT_OWNER);
        users.push(VAULT_MANAGER_OWNER);
        users.push(PROTOCOL);
        users.push(LIQUIDATOR);

        // TODO: tokens, smartVaultYieldManager.addHypervisorData, etc
    }
}

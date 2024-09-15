// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import {PropertiesConstants} from "@crytic/util/PropertiesConstants.sol";
import {vm} from "@chimera/Hevm.sol";

import {SmartVaultFixture, SmartVaultV4} from "../fixtures/SmartVaultFixture.sol";

abstract contract Setup is BaseSetup, PropertiesConstants, SmartVaultFixture {
    // address[] internal users;
    SmartVaultV4 internal smartVault;

    function setup() internal virtual override {
        super.setUp();

        // NOTE: this isn't necessary since we will always prank the correct address
        // set up users that will be used to call target functions
        // users.push(USER1);
        // users.push(USER2);
        // users.push(USER3);
        // users.push(VAULT_OWNER);
        // users.push(VAULT_MANAGER_OWNER);
        // users.push(PROTOCOL);
        // users.push(LIQUIDATOR);

        // create a SmartVaultV4 instance
        smartVault = _createSmartVaultViaManager(VAULT_OWNER);

        vm.deal(address(smartVault), 25 ether);
        weth.mint(address(smartVault), 25 * 10 ** weth.decimals());
        wbtc.mint(address(smartVault), 1 * 10 ** wbtc.decimals());
        link.mint(address(smartVault), 5_000 * 10 ** link.decimals());
        usdc.mint(address(smartVault), 62_500 * 10 ** usdc.decimals());
    }
}

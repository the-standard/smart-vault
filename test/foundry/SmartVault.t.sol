// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SmartVaultFixture} from "./fixtures/SmartVaultFixture.sol";

contract SmartVaultTest is SmartVaultFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_true() public {
        assertTrue(true);
    }
}

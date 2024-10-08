// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {SmartVaultYieldManagerFixture} from "./fixtures/SmartVaultYieldManagerFixture.sol";

contract SmartVaultYieldManagerTest is SmartVaultYieldManagerFixture, Test {
    function setUp() public override {
        super.setUp();
    }

    function test_addHypervisorData() public {
        // expect revert addHypervisorData
        // owner call + assert
    }

    function test_removeHypervisorData() public {
        // expect revert removeHypervisorData
        // owner call + assert
    }

    function test_setFeeData() public {
        // expect revert setFeeData
        // owner call + assert
    }

    function test_deposit() public {
        // deposit native collateral
        // deposit 6 decimal collateral
        // deposit 18 decimal collateral
        // deposit invalid collateral
        // deposit 0/MIN_USDS_PERCENTAGE/HUNDRED_PC usds percentage
        // expect emit deposit
        // assert addresses + balances + fee
    }

    function test_withdraw() public {
        // withdraw usds hypervisor
        // withdraw other hypervisor
        // swap to native collateral
        // swap to 6 decimal collateral
        // swap to 18 decimal collateral
        // swap to invalid collateral
        // expect emit withdraw
        // assert addresses + balances + fee
    }
}

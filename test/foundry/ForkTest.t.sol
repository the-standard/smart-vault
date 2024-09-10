// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./fixtures/ForkFixture.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

contract ForkTest is ForkFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_nativeSwap() public {
        vm.deal(address(vault), 1 ether);

        vm.assertFalse(vault.undercollateralised());

        vm.prank(VAULT_OWNER);
        vault.swap(NATIVE, WBTC_SYMBOL, 0.5 ether, 0);
    }

    function test_wethSwap() public {
        vm.deal(VAULT_OWNER, 1 ether);

        vm.prank(VAULT_OWNER);
        IWETH(WETH_ADDRESS).deposit{value: 1 ether}();

        vm.prank(VAULT_OWNER);
        IWETH(WETH_ADDRESS).transfer(address(vault), 1 ether);
        vm.assertFalse(vault.undercollateralised());

        vm.deal(address(vault), 0.0025 ether); // to cover fee

        vm.prank(VAULT_OWNER);
        vm.expectRevert();
        vault.swap(WETH_SYMBOL, WBTC_SYMBOL, 0.5 ether, 0);
    }

    function test_depositAndWithdrawYield() public {
        vm.deal(address(vault), 1 ether);

        vm.prank(VAULT_OWNER);
        vault.depositYield(NATIVE, 1e4);

        vm.prank(VAULT_OWNER);
        vault.withdrawYield(address(usdsHypervisor), NATIVE);

        vm.prank(VAULT_OWNER);
        vault.withdrawYield(WBTC_HYPERVISOR_ADDRESS, NATIVE);
    }
}

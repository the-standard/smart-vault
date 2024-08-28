// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {SmartVaultFixture, SmartVaultV4} from "./fixtures/SmartVaultFixture.sol";

contract SmartVaultTest is SmartVaultFixture, Test {
    function setUp() public override {
        super.setUp();
    }

    function test_ownership() public {
        address newOwner = makeAddr("New owner");
        SmartVaultV4 smartVault = smartVaults[VAULT_OWNER][0].vault;

        vm.expectRevert("InvalidUser");
        smartVault.setOwner(newOwner);
        
        vm.prank(VAULT_OWNER);
        smartVault.setOwner(newOwner);
        assertEq(smartVault.owner(), newOwner);
    }

    function test_addCollateral() public {
        // TODO: set up all mock collaterals and feeds in Common
        // add native collateral
        // add 6 decimal collateral
        // add 18 decimal collateral
        // expect revert 24 decimal collateral
    }

    function test_removeCollateralNotUndercollateralised() public {
        // remove native collateral
        // remove 6 decimal collateral
        // remove 18 decimal collateral
        // remove non-collateral tokens
    }

    function test_mintUsds() public {
        // cannot mint if undercollateralised (no collateral)
        // expect revert not owner
        // expect emit USDsMinted
        // assert balances + fee
    }
    
    function test_burnUsds() public {
        // expect revert Overrepay
        // expect emit USDsBurned
        // assert balances + fees
    }

    function test_liquidation() public {
        // undercollateralised false with no collateral (+ canRemoveCollateral)
        // undercollateralised false with collateral and no borrowing
        // undercollateralised false with collateral and borrowing before price decrease
        // expect revert liquidate "vault-not-undercollateralised"
        // undercollateralised true with collateral and borrowing after price decrease
        // expect revert liquidate InvalidUser
        // assert balances + state
        // expect revert mint VaultLiquidated
    }

    function test_swap() public {
        // expect revert swap InvalidUser
        // swap native
        // swap 6 decimal collateral
        // swap 18 decimal collateral
        // expect revert swap invalid token in/out
    }

    function test_swapWithMinimum() public {
        // as above using slippage parameter
    }

    function test_yieldDeposit() public {
        // TODO: in fixture: deploy mock gamma vaults, add hypervisor data in manager, set ratio on uni proxy, set swap router rates
        // expect revert not owner
        // puts 100% of collateral into yield
        // assert balances/events/etc
    }

    function test_yieldWithdraw() public {
        // deposit
        // withdraw + assert balances/fees/etc
    }

    function test_yieldCollateralCheck() public {
        // slippage check revert during deposit/withdrawal
    }

    function test_yieldSwapRatio() public {
        // reverts if no convergence
    }
}

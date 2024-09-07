// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IHypervisor} from "contracts/interfaces/IHypervisor.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

import {SmartVaultFixture, SmartVaultV4} from "./fixtures/SmartVaultFixture.sol";

contract SmartVaultTest is SmartVaultFixture, Test {
    SmartVaultV4 smartVault;
    
    event CollateralRemoved(bytes32 symbol, uint256 amount, address to);
    event AssetRemoved(address token, uint256 amount, address to);
    event USDsMinted(address to, uint256 amount, uint256 fee);
    event USDsBurned(uint256 amount, uint256 fee);

    function setUp() public override {
        super.setUp();

        smartVault = _createSmartVaultViaManager(VAULT_OWNER);
    }

    function test_ownership() public {
        address newOwner = makeAddr("New owner");

        vm.expectRevert(SmartVaultV4.InvalidUser.selector);
        smartVault.setOwner(newOwner);

        vm.prank(address(smartVaultManager));
        smartVault.setOwner(newOwner);
        assertEq(smartVault.owner(), newOwner);
    }

    function test_addCollateral() public {
        uint256 usdCollateral = smartVault.status().totalCollateralValue;
        assertEq(usdCollateral, 0);
        
        // add each collateral
        _addCollateral(smartVault);

        // expect revert >18 decimal collateral
        ERC20Mock largeDecimals = new ERC20Mock("Large Decimals", "XXL", 24);
        ChainlinkMock clXxlUsd = new ChainlinkMock("XXL/USD");
        tokenManager.addAcceptedToken(address(largeDecimals), address(clXxlUsd));
        uint256 xxlAmount = 10 ** largeDecimals.decimals();
        largeDecimals.mint(address(smartVault), xxlAmount);
        assertEq(largeDecimals.balanceOf(address(smartVault)), xxlAmount);
        vm.expectRevert(stdError.arithmeticError);
        smartVault.status().totalCollateralValue;
    }

    // TODO: also test:
    // * this functionality with minted USDs
    // * the unhappy path
    // * remove native via removeCollateral reverts
    // * remove non-collateral asset via removeCollateral reverts
    // * removing collateral via removeAsset - happy and unhappy paths
    function test_removeCollateralNotUndercollateralised() public {
        _addCollateral(smartVault);

        // remove native collateral
        uint256 nativeAmount = address(smartVault).balance;
        assertTrue(nativeAmount != 0);
        uint256 nativeBefore = VAULT_OWNER.balance;
        vm.startPrank(VAULT_OWNER);
        smartVault.removeCollateralNative(nativeAmount, payable(VAULT_OWNER));
        vm.stopPrank();
        assertEq(address(smartVault).balance, 0);
        assertEq(VAULT_OWNER.balance, nativeBefore + nativeAmount);

        // remove weth collateral
        uint256 wethAmount = weth.balanceOf(address(smartVault));
        assertTrue(weth.balanceOf(address(smartVault)) != 0);
        uint256 wethBefore = weth.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit CollateralRemoved(bytes32(bytes(weth.symbol())), wethAmount, VAULT_OWNER);
        smartVault.removeCollateral(bytes32(bytes(weth.symbol())), wethAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(weth.balanceOf(address(smartVault)), 0);
        assertEq(weth.balanceOf(VAULT_OWNER), wethBefore + wethAmount);

        // remove wbtc collateral
        uint256 wbtcAmount = wbtc.balanceOf(address(smartVault));
        assertTrue(wbtc.balanceOf(address(smartVault)) != 0);
        uint256 wbtcBefore = wbtc.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit CollateralRemoved(bytes32(bytes(wbtc.symbol())), wbtcAmount, VAULT_OWNER);
        smartVault.removeCollateral(bytes32(bytes(wbtc.symbol())), wbtcAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(wbtc.balanceOf(address(smartVault)), 0);
        assertEq(wbtc.balanceOf(VAULT_OWNER), wbtcBefore + wbtcAmount);

        // remove link collateral
        uint256 linkAmount = link.balanceOf(address(smartVault));
        assertTrue(link.balanceOf(address(smartVault)) != 0);
        uint256 linkBefore = link.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit CollateralRemoved(bytes32(bytes(link.symbol())), linkAmount, VAULT_OWNER);
        smartVault.removeCollateral(bytes32(bytes(link.symbol())), linkAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(link.balanceOf(address(smartVault)), 0);
        assertEq(link.balanceOf(VAULT_OWNER), linkBefore + linkAmount);

        // add & remove non-collateral token
        uint256 usdcAmount = 10 ** usdc.decimals();
        assertEq(usdc.balanceOf(address(smartVault)), 0);
        usdc.mint(address(smartVault), usdcAmount);
        assertEq(usdc.balanceOf(address(smartVault)), usdcAmount);
        uint256 usdcBefore = usdc.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit AssetRemoved(address(usdc), usdcAmount, VAULT_OWNER);
        smartVault.removeAsset(address(usdc), usdcAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(usdc.balanceOf(address(smartVault)), 0);
        assertEq(usdc.balanceOf(VAULT_OWNER), usdcBefore + usdcAmount);
    }

    function test_mintUsds() public {
        uint256 usdsDecimals = usds.decimals();
        
        // cannot mint if undercollateralised (no collateral)
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.mint(VAULT_OWNER, 100 * usdsDecimals);
        vm.stopPrank();

        _addCollateral(smartVault);

        // expect revert not owner
        vm.expectRevert(SmartVaultV4.InvalidUser.selector);
        smartVault.mint(VAULT_OWNER, 100 * usdsDecimals);

        // expect emit USDsMinted
        address to = VAULT_OWNER;
        uint256 amount = 100 * usdsDecimals;
        uint256 fee = amount * PROTOCOL_FEE_RATE / smartVaultManager.HUNDRED_PC();
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit USDsMinted(to, amount, fee);
        smartVault.mint(to, amount);
        vm.stopPrank();

        // assert balances + fee
        assertEq(usds.balanceOf(to), amount);
        assertEq(smartVault.status().minted, amount + fee);
        assertEq(smartVault.undercollateralised(), false);
        assertEq(usds.balanceOf(PROTOCOL), fee);
    }

    function test_burnUsds() public {
        uint256 usdsAmountBefore = 100 * 10 ** usds.decimals();

        // expect revert Overrepay
        vm.expectRevert(SmartVaultV4.Overrepay.selector);
        smartVault.burn(usdsAmountBefore);

        _addCollateral(smartVault);
        uint256 mintFee = _mintUsds(smartVault, VAULT_OWNER, usdsAmountBefore);
        
        // expect emit USDsBurned
        uint256 usdsAmountBurned = usdsAmountBefore * 90 / 100;
        uint256 burnFee = smartVaultManager.burnFeeRate() * usdsAmountBurned / smartVaultManager.HUNDRED_PC();
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit USDsBurned(usdsAmountBurned, burnFee);
        smartVault.burn(usdsAmountBurned);
        vm.stopPrank();
        
        // assert balances + fees
        assertEq(usds.balanceOf(VAULT_OWNER), usdsAmountBefore - usdsAmountBurned - burnFee);
        assertEq(smartVault.status().minted, usdsAmountBefore + mintFee - usdsAmountBurned);
        assertEq(usds.balanceOf(PROTOCOL), mintFee + burnFee);
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

        // expect revert 24 decimal Hypervisor token
        // ERC20Mock largeDecimals = new ERC20Mock("Large Decimals", "XXL", 24);
        // largeDecimals.mint(address(smartVault), 1);
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

    function test_pocDepositYieldRemoveCollateral() public {
        // borrow usds -> deposit yield -> SmartVaultV4::removeAsset (hypervisor token) -> profit
        // what happens to liquidation?

        SmartVaultV4 smartVault = smartVaults[VAULT_OWNER][0].vault;

        vm.deal(VAULT_OWNER, 1 ether);
        vm.startPrank(VAULT_OWNER);
        address(smartVault).call{value: 1 ether}("");
        SmartVaultV4.Status memory status = smartVault.status();
        console.log("USDS balance of VAULT_OWNER before mint: %s", usds.balanceOf(VAULT_OWNER));
        console.log("USDS balance of SmartVault before mint: %s", usds.balanceOf(address(smartVault)));
        smartVault.mint(VAULT_OWNER, status.maxMintable * 90 / 100);
        console.log("USDS balance of VAULT_OWNER before depositYield: %s", usds.balanceOf(VAULT_OWNER));
        console.log("USDS balance of SmartVault before depositYield: %s", usds.balanceOf(address(smartVault)));
        console.log("Undercollateralised before depositYield: %s", smartVault.undercollateralised());
        smartVault.depositYield(NATIVE, 1e5);
        SmartVaultV4.YieldPair[] memory yieldPairs = smartVault.yieldAssets();
        assertEq(yieldPairs.length, 1);
        address hypervisor = yieldPairs[0].hypervisor;
        console.log("Hypervisor balance of VAULT_OWNER before removeAsset: %s", IHypervisor(hypervisor).balanceOf(VAULT_OWNER));
        console.log("Hypervisor balance of SmartVault before removeAsset: %s", IHypervisor(hypervisor).balanceOf(address(smartVault)));
        console.log("USDS balance of VAULT_OWNER before removeAsset: %s", usds.balanceOf(VAULT_OWNER));
        console.log("USDS balance of SmartVault before removeAsset: %s", usds.balanceOf(address(smartVault)));
        console.log("Undercollateralised before removeAsset: %s", smartVault.undercollateralised());
        smartVault.removeAsset(yieldPairs[0].hypervisor, IHypervisor(hypervisor).balanceOf(address(smartVault)), VAULT_OWNER);
        vm.stopPrank();

        console.log("Hypervisor balance of VAULT_OWNER after: %s", IHypervisor(hypervisor).balanceOf(VAULT_OWNER));
        console.log("Hypervisor balance of SmartVault after: %s", IHypervisor(hypervisor).balanceOf(address(smartVault)));
        console.log("USDS balance of VAULT_OWNER after: %s", usds.balanceOf(VAULT_OWNER));
        console.log("USDS balance of SmartVault after: %s", usds.balanceOf(address(smartVault)));
        console.log("Undercollateralised after: %s", smartVault.undercollateralised());
    }

    // Helper functions
    function _addCollateral(SmartVaultV4 vault) internal {
        uint256 usdCollateral = smartVault.status().totalCollateralValue;

        // add native collateral
        uint256 nativeAmount = 2 ether;
        uint256 nativeValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        address(smartVault).call{value: nativeAmount}("");
        assertEq(address(smartVault).balance, nativeAmount);
        assertEq(_getVaultCollateralVault(smartVault), usdCollateral + nativeValue);

        // add weth collateral
        usdCollateral = _getVaultCollateralVault(smartVault);
        uint256 wethAmount = nativeAmount;
        uint256 wethValue = DEFAULT_ETH_USD_PRICE * wethAmount;
        weth.mint(address(smartVault), wethAmount);
        assertEq(weth.balanceOf(address(smartVault)), wethAmount);
        assertEq(_getVaultCollateralVault(smartVault), usdCollateral + wethValue);

        // add wbtc collateral
        usdCollateral = _getVaultCollateralVault(smartVault);
        uint256 wbtcAmount = nativeAmount * 10 ** wbtc.decimals() / DEFAULT_WBTC_ETH_MULTIPLIER / 1e18;
        uint256 wbtcValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        wbtc.mint(address(smartVault), wbtcAmount);
        assertEq(wbtc.balanceOf(address(smartVault)), wbtcAmount);
        assertEq(_getVaultCollateralVault(smartVault), usdCollateral + wbtcValue);

        // add link collateral
        usdCollateral = _getVaultCollateralVault(smartVault);
        uint256 linkAmount = nativeAmount * 10 ** link.decimals() * DEFAULT_LINK_ETH_DIVISOR / 1e18;
        uint256 linkValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        link.mint(address(smartVault), linkAmount);
        assertEq(link.balanceOf(address(smartVault)), linkAmount);
        assertEq(_getVaultCollateralVault(smartVault), usdCollateral + linkValue);
    }

    function _mintUsds(SmartVaultV4 vault, address to, uint256 amount) internal returns (uint256 fee) {
        fee = amount * PROTOCOL_FEE_RATE / 1e5;
        vm.prank(vault.owner());
        vault.mint(to, amount);
    }
}

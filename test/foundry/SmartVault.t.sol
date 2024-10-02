// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test, stdError} from "forge-std/Test.sol";

import {IHypervisor} from "contracts/interfaces/IHypervisor.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

import {SmartVaultFixture, SmartVaultV4} from "./fixtures/SmartVaultFixture.sol";

contract SmartVaultTest is SmartVaultFixture, Test {
    SmartVaultV4 smartVault;

    // SmartVaultV4 events
    event CollateralRemoved(bytes32 symbol, uint256 amount, address to);
    event AssetRemoved(address token, uint256 amount, address to);
    event USDsMinted(address to, uint256 amount, uint256 fee);
    event USDsBurned(uint256 amount, uint256 fee);

    // SmartVaultYieldManager events
    event Deposit(address indexed smartVault, address indexed token, uint256 amount, uint256 usdPercentage);
    event Withdraw(address indexed smartVault, address indexed token, address hypervisor, uint256 amount);

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
        clXxlUsd.setPrice(1e8);
        tokenManager.addAcceptedToken(address(largeDecimals), address(clXxlUsd));
        uint256 xxlAmount = 10 ** largeDecimals.decimals();
        uint256 xxlAmountUSD = 1 ether;
        usdCollateral = smartVault.status().totalCollateralValue;
        largeDecimals.mint(address(smartVault), xxlAmount);
        assertEq(largeDecimals.balanceOf(address(smartVault)), xxlAmount);
        assertEq(smartVault.status().totalCollateralValue, usdCollateral + xxlAmountUSD);
    }

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
        assertTrue(wethAmount != 0);
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
        assertTrue(wbtcAmount != 0);
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
        assertTrue(linkAmount != 0);
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

        assertFalse(smartVault.undercollateralised());
    }

    function test_removeCollateralUndercollateralised() public {
        _addCollateral(smartVault);

        uint256 usdsAmount = smartVault.status().maxMintable * 99 / 100;
        vm.prank(VAULT_OWNER);
        smartVault.mint(VAULT_OWNER, usdsAmount);

        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeCollateralNative(address(smartVault).balance, payable(VAULT_OWNER));
        vm.stopPrank();

        uint256 wethAmount = weth.balanceOf(address(smartVault));
        bytes32 wethSymbol = bytes32(bytes(weth.symbol()));
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeCollateral(wethSymbol, wethAmount, VAULT_OWNER);
        vm.stopPrank();

        uint256 wbtcAmount = wbtc.balanceOf(address(smartVault));
        bytes32 wbtcSymbol = bytes32(bytes(wbtc.symbol()));
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeCollateral(wbtcSymbol, wbtcAmount, VAULT_OWNER);
        vm.stopPrank();

        uint256 linkAmount = link.balanceOf(address(smartVault));
        bytes32 linkSymbol = bytes32(bytes(link.symbol()));
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeCollateral(linkSymbol, linkAmount, VAULT_OWNER);
        vm.stopPrank();

        // ETH/WETH moons, so remove WBTC collateral
        (, int256 nativeUsdPrice,,,) = clNativeUsd.latestRoundData();
        clNativeUsd.setPrice(nativeUsdPrice * 20);
        wbtcAmount = wbtc.balanceOf(address(smartVault));
        assertTrue(wbtcAmount != 0);
        uint256 wbtcBefore = wbtc.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit CollateralRemoved(wbtcSymbol, wbtcAmount, VAULT_OWNER);
        smartVault.removeCollateral(wbtcSymbol, wbtcAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(wbtc.balanceOf(address(smartVault)), 0);
        assertEq(wbtc.balanceOf(VAULT_OWNER), wbtcBefore + wbtcAmount);

        assertFalse(smartVault.undercollateralised());
    }

    function test_removeCollateralFunctions() public {
        _addCollateral(smartVault);

        // removing native via removeCollateral reverts
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert("Address: call to non-contract");
        smartVault.removeCollateral(NATIVE, address(smartVault).balance, VAULT_OWNER);
        vm.stopPrank();

        // removing non-collateral asset via removeCollateral reverts
        uint256 usdcAmount = 10 ** usdc.decimals();
        assertEq(usdc.balanceOf(address(smartVault)), 0);
        usdc.mint(address(smartVault), usdcAmount);
        assertEq(usdc.balanceOf(address(smartVault)), usdcAmount);
        uint256 usdcBefore = usdc.balanceOf(VAULT_OWNER);
        bytes32 usdcSymbol = bytes32(bytes(usdc.symbol()));
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert("err-invalid-token");
        smartVault.removeCollateral(usdcSymbol, usdcAmount, VAULT_OWNER);
        vm.stopPrank();

        // TODO: also test:
        // removing collateral via removeAsset reverts if undercollateralised
        uint256 usdsAmount = smartVault.status().maxMintable * 99 / 100;
        vm.prank(VAULT_OWNER);
        smartVault.mint(VAULT_OWNER, usdsAmount);

        // remove native collateral fails
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeAsset(address(0), address(smartVault).balance, VAULT_OWNER);

        // remove weth collateral fails
        vm.startPrank(VAULT_OWNER);
        uint256 wethAmount = weth.balanceOf(address(smartVault));
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeAsset(address(weth), wethAmount, VAULT_OWNER);

        // remove wbtc collateral fails
        vm.startPrank(VAULT_OWNER);
        uint256 wbtcAmount = wbtc.balanceOf(address(smartVault));
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeAsset(address(wbtc), wbtcAmount, VAULT_OWNER);

        // remove link collateral fails
        vm.startPrank(VAULT_OWNER);
        uint256 linkAmount = link.balanceOf(address(smartVault));
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeAsset(address(link), linkAmount, VAULT_OWNER);

        // WBTC & LINK moon, so remove ETH/WETH collateral
        (, int256 wbtcUsdPrice,,,) = clWbtcUsd.latestRoundData();
        clWbtcUsd.setPrice(wbtcUsdPrice * 100);
        (, int256 linkUsdPrice,,,) = clLinkUsd.latestRoundData();
        clLinkUsd.setPrice(linkUsdPrice * 100);

        // remove ETH via removeAsset
        uint256 nativeAmount = address(smartVault).balance;
        assertTrue(nativeAmount != 0);
        uint256 nativeBefore = VAULT_OWNER.balance;
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit CollateralRemoved(NATIVE, nativeAmount, VAULT_OWNER);
        smartVault.removeAsset(address(0), nativeAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(address(smartVault).balance, 0);
        assertEq(VAULT_OWNER.balance, nativeBefore + nativeAmount);

        wethAmount = weth.balanceOf(address(smartVault));
        assertTrue(wethAmount != 0);
        uint256 wethBefore = weth.balanceOf(VAULT_OWNER);
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, false, false, true);
        emit AssetRemoved(address(weth), wethAmount, VAULT_OWNER);
        smartVault.removeAsset(address(weth), wethAmount, VAULT_OWNER);
        vm.stopPrank();
        assertEq(weth.balanceOf(address(smartVault)), 0);
        assertEq(weth.balanceOf(VAULT_OWNER), wethBefore + wethAmount);

        assertFalse(smartVault.undercollateralised());
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
        // undercollateralised false with no collateral
        assertFalse(smartVault.undercollateralised());

        // undercollateralised false with collateral and no borrowing
        _addCollateral(smartVault);
        assertFalse(smartVault.undercollateralised());

        // undercollateralised false with collateral and borrowing before price decrease
        _mintUsds(smartVault, VAULT_OWNER, smartVault.status().maxMintable * 90 / 100);
        assertFalse(smartVault.undercollateralised());
        address liquidator = makeAddr("liquidator");

        // expect revert liquidate
        vm.startPrank(address(smartVaultManager));
        vm.expectRevert(SmartVaultV4.NotUndercollateralised.selector);
        smartVault.liquidate(liquidator);
        vm.stopPrank();

        // undercollateralised true with collateral and borrowing after price decrease
        (, int256 nativeUsdPrice,,,) = clNativeUsd.latestRoundData();
        clNativeUsd.setPrice(nativeUsdPrice / 10);
        assertTrue(smartVault.undercollateralised());

        // try to liquidate with non-manager account
        vm.expectRevert(SmartVaultV4.InvalidUser.selector);
        smartVault.liquidate(liquidator);

        // liquidate as manager
        uint256 nativeBalanceBefore = address(smartVault).balance;
        uint256 wethBalanceBefore = weth.balanceOf(address(smartVault));
        uint256 wbtcBalanceBefore = wbtc.balanceOf(address(smartVault));
        uint256 linkBalanceBefore = link.balanceOf(address(smartVault));

        vm.prank(address(smartVaultManager));
        smartVault.liquidate(liquidator);

        // assert balances + state
        assertTrue(smartVault.status().liquidated);
        assertEq(address(smartVault).balance, 0);
        assertEq(weth.balanceOf(address(smartVault)), 0);
        assertEq(wbtc.balanceOf(address(smartVault)), 0);
        assertEq(link.balanceOf(address(smartVault)), 0);
        assertEq(smartVault.status().totalCollateralValue, 0);
        assertEq(smartVault.status().maxMintable, 0);

        assertEq(liquidator.balance, nativeBalanceBefore);
        assertEq(weth.balanceOf(liquidator), wethBalanceBefore);
        assertEq(wbtc.balanceOf(liquidator), wbtcBalanceBefore);
        assertEq(link.balanceOf(liquidator), linkBalanceBefore);

        // expect revert mint VaultLiquidated
        uint256 usdsAmount = 100 * 10 ** usds.decimals();
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert(SmartVaultV4.VaultLiquidated.selector);
        smartVault.mint(VAULT_OWNER, usdsAmount);
    }

    // NOTE: best to fork test swaps
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

    // NOTE: should also fork test yield deposits due to intermediate swaps
    function test_yieldDeposit() public {
        _addCollateral(smartVault);

        uint256 nativeAmount = address(smartVault).balance;
        uint256 wethAmount = weth.balanceOf(address(smartVault));
        uint256 stablePercentage = 1e5;

        // revert invalid owner
        vm.expectRevert(SmartVaultV4.InvalidUser.selector);
        smartVault.depositYield(NATIVE, stablePercentage, 5e4, block.timestamp + 60);

        // cache state before
        uint256 wbtcHypervisorBalance = wbtcHypervisor.balanceOf(address(smartVault));
        uint256 wbtcHypervisorTotalSupply = wbtcHypervisor.totalSupply();
        (uint256 wbtcHypervisorUnderlying0, uint256 wbtcHypervisorUnderlying1) = wbtcHypervisor.getTotalAmounts();
        uint256 usdsHypervisorBalance = usdsHypervisor.balanceOf(address(smartVault));
        uint256 usdsHypervisorTotalSupply = usdsHypervisor.totalSupply();
        (uint256 usdsHypervisorUnderlying0, uint256 usdsHypervisorUnderlying1) = usdsHypervisor.getTotalAmounts();

        // put 100% of collateral into yield
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(true, true, false, true);
        emit Deposit(address(smartVault), address(weth), nativeAmount + wethAmount, stablePercentage);
        smartVault.depositYield(NATIVE, stablePercentage, 5e4, block.timestamp + 60);

        // assert no changes to wbtc hypervisor
        assertEq(wbtcHypervisor.balanceOf(address(smartVault)), wbtcHypervisorBalance);
        assertEq(wbtcHypervisor.totalSupply(), wbtcHypervisorTotalSupply);
        (uint256 wbtcHypervisorUnderlying0After, uint256 wbtcHypervisorUnderlying1After) =
            wbtcHypervisor.getTotalAmounts();
        assertEq(wbtcHypervisorUnderlying0After, wbtcHypervisorUnderlying0);
        assertEq(wbtcHypervisorUnderlying1After, wbtcHypervisorUnderlying1);

        // assert usds hypervisor balances
        assertGt(usdsHypervisor.balanceOf(address(smartVault)), usdsHypervisorBalance);
        assertGt(usdsHypervisor.totalSupply(), usdsHypervisorTotalSupply);
        (uint256 usdsHypervisorUnderlying0After, uint256 usdsHypervisorUnderlying1After) =
            usdsHypervisor.getTotalAmounts();
        assertGe(usdsHypervisorUnderlying0After, usdsHypervisorUnderlying0);
        assertGe(usdsHypervisorUnderlying1After, usdsHypervisorUnderlying1);

        // expect revert 24 decimal Hypervisor token
        // ERC20Mock largeDecimals = new ERC20Mock("Large Decimals", "XXL", 24);
        // largeDecimals.mint(address(smartVault), 1);
    }

    function test_yieldWithdraw() public {
        // add collateral & deposit
        _addCollateral(smartVault);

        uint256 nativeAmount = address(smartVault).balance;
        uint256 wethAmount = weth.balanceOf(address(smartVault));
        uint256 stablePercentage = 1e5;

        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(true, true, false, true);
        emit Deposit(address(smartVault), address(weth), nativeAmount + wethAmount, stablePercentage);
        smartVault.depositYield(NATIVE, stablePercentage, 5e4, block.timestamp + 60);

        // withdraw + assert balances/fees/etc
        uint256 nativeBefore = address(smartVault).balance;
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(true, true, false, false);
        emit Withdraw(address(smartVault), address(weth), address(usdsHypervisor), 0);
        smartVault.withdrawYield(address(usdsHypervisor), NATIVE, 5e4, block.timestamp + 60);
        vm.stopPrank();
        assertGt(address(smartVault).balance, nativeAmount + wethAmount - nativeBefore);
    }

    function test_yieldCollateralCheck() public {
        // TODO: slippage check revert during deposit/withdrawal
        // nuke collateral value & assert undercollateralised/significant collateral drop
    }

    // NOTE: new implementation tested with differential fork test
    function test_yieldSwapRatio() public {
        // reverts if no convergence
    }

    function test_collateralCheckOnHypervisorRemoval() public {
        // borrow usds -> deposit yield -> SmartVaultV4::removeAsset (hypervisor token) -> profit

        vm.deal(VAULT_OWNER, 1 ether);
        vm.startPrank(VAULT_OWNER);
        address(smartVault).call{value: 1 ether}("");
        SmartVaultV4.Status memory status = smartVault.status();
        smartVault.mint(VAULT_OWNER, status.maxMintable * 90 / 100);
        smartVault.depositYield(NATIVE, 1e5, 5e4, block.timestamp + 60);
        status = smartVault.status();
        SmartVaultV4.YieldPair[] memory yieldPairs = smartVault.yieldAssets();
        assertEq(yieldPairs.length, 1);
        address hypervisor = yieldPairs[0].hypervisor;
        status = smartVault.status();
        yieldPairs = smartVault.yieldAssets();

        uint256 hypervisorBalance = IHypervisor(hypervisor).balanceOf(address(smartVault));
        vm.expectRevert(SmartVaultV4.Undercollateralised.selector);
        smartVault.removeAsset(yieldPairs[0].hypervisor, hypervisorBalance, VAULT_OWNER);
    }

    // Helper functions
    function _addCollateral(SmartVaultV4 vault) internal {
        uint256 usdCollateral = smartVault.status().totalCollateralValue;

        // add native collateral
        uint256 nativeAmount = 2 ether;
        uint256 nativeValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        address(smartVault).call{value: nativeAmount}("");
        assertEq(address(smartVault).balance, nativeAmount);
        assertEq(_getVaultCollateralVaulue(smartVault), usdCollateral + nativeValue);

        // add weth collateral
        usdCollateral = _getVaultCollateralVaulue(smartVault);
        uint256 wethAmount = nativeAmount;
        uint256 wethValue = DEFAULT_ETH_USD_PRICE * wethAmount;
        weth.mint(address(smartVault), wethAmount);
        vm.deal(address(weth), address(weth).balance + wethAmount);
        assertEq(weth.balanceOf(address(smartVault)), wethAmount);
        assertEq(_getVaultCollateralVaulue(smartVault), usdCollateral + wethValue);

        // add wbtc collateral
        usdCollateral = _getVaultCollateralVaulue(smartVault);
        uint256 wbtcAmount = nativeAmount * 10 ** wbtc.decimals() / DEFAULT_WBTC_ETH_MULTIPLIER / 1e18;
        uint256 wbtcValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        wbtc.mint(address(smartVault), wbtcAmount);
        assertEq(wbtc.balanceOf(address(smartVault)), wbtcAmount);
        assertEq(_getVaultCollateralVaulue(smartVault), usdCollateral + wbtcValue);

        // add link collateral
        usdCollateral = _getVaultCollateralVaulue(smartVault);
        uint256 linkAmount = nativeAmount * 10 ** link.decimals() * DEFAULT_LINK_ETH_DIVISOR / 1e18;
        uint256 linkValue = DEFAULT_ETH_USD_PRICE * nativeAmount;
        link.mint(address(smartVault), linkAmount);
        assertEq(link.balanceOf(address(smartVault)), linkAmount);
        assertEq(_getVaultCollateralVaulue(smartVault), usdCollateral + linkValue);
    }

    function _mintUsds(SmartVaultV4 vault, address to, uint256 amount) internal returns (uint256 fee) {
        fee = amount * PROTOCOL_FEE_RATE / 1e5;
        vm.prank(vault.owner());
        vault.mint(to, amount);
    }
}

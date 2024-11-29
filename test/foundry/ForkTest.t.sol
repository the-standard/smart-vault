// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

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
        vault.swap(NATIVE, WBTC_SYMBOL, 0.5 ether, 0, 500, block.timestamp + 60);
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
        vault.swap(WETH_SYMBOL, WBTC_SYMBOL, 0.5 ether, 0, 500, block.timestamp + 60);
    }

    function test_depositAndWithdrawYield() public {
        vm.deal(address(vault), 1e18);
        _deal(WBTC, WBTC_WHALE, address(this));
        _deal(WETH, WETH_WHALE, VAULT_OWNER);
        _deal(ARB, ARB_WHALE, address(this));
        _deal(LINK, LINK_WHALE, address(this));
        _deal(GMX, GMX_WHALE, address(this));
        _deal(RDNT, RDNT_WHALE, address(this));
        WBTC.transfer(address(vault), 1e6);
        ARB.transfer(address(vault), 500e18);
        LINK.transfer(address(vault), 200e18);
        GMX.transfer(address(vault), 10e18);
        RDNT.transfer(address(vault), 200e18);

        vm.startPrank(VAULT_OWNER);
        vault.depositYield(NATIVE, 1e4, 5e4, block.timestamp + 60);
        vault.depositYield(WBTC_SYMBOL, 5e4, 5e4, block.timestamp + 60);
        vault.depositYield(ARB_SYMBOL, 1e4, 5e4, block.timestamp + 60);
        vault.depositYield(LINK_SYMBOL, 1e4, 5e4, block.timestamp + 60);
        vault.depositYield(GMX_SYMBOL, 1e4, 5e4, block.timestamp + 60);
        vault.depositYield(RDNT_SYMBOL, 1e4, 5e4, block.timestamp + 60);

        vault.withdrawYield(USDS_HYPERVISOR_ADDRESS, NATIVE, 5e4, block.timestamp + 60);
        vault.withdrawYield(WBTC_HYPERVISOR_ADDRESS, WBTC_SYMBOL, 5e4, block.timestamp + 60);
        vault.withdrawYield(ARB_HYPERVISOR_ADDRESS, ARB_SYMBOL, 5e4, block.timestamp + 60);
        vault.withdrawYield(LINK_HYPERVISOR_ADDRESS, LINK_SYMBOL, 5e4, block.timestamp + 60);
        vault.withdrawYield(GMX_HYPERVISOR_ADDRESS, GMX_SYMBOL, 5e4, block.timestamp + 60);
        vault.withdrawYield(RDNT_HYPERVISOR_ADDRESS, RDNT_SYMBOL, 5e4, block.timestamp + 60);

        // put weth in after eth deposit is done because of eth yield deposit clearing out the weth balance
        WETH.transfer(address(vault), 1e18);
        vault.depositYield(WETH_SYMBOL, 1e4, 5e4, block.timestamp + 60);
        vault.withdrawYield(WBTC_HYPERVISOR_ADDRESS, WETH_SYMBOL, 5e4, block.timestamp + 60);
        vm.stopPrank();
    }

    function test_autoRedemption() public {
        // // make USDs cheaper, so redemption will be required:
        // uint256 usdsDump = 50000 ether;
        // USDS.approve(UNISWAP_ROUTER_ADDRESS, usdsDump);
        // ISwapRouter(UNISWAP_ROUTER_ADDRESS).exactInputSingle(
        //     ISwapRouter.ExactInputSingleParams({
        //         tokenIn: USDS_ADDRESS,
        //         tokenOut: USDC_ADDRESS,
        //         fee: RAMSES_FEE,
        //         recipient: address(this),
        //         deadline: block.timestamp,
        //         amountIn: usdsDump,
        //         amountOutMinimum: 0,
        //         sqrtPriceLimitX96: 0
        //     })
        // );

        // uint256 ethCollateral = 1 ether;
        // vm.deal(address(vault), 1 ether);

        // vm.prank(VAULT_OWNER);
        // vault.mint(VAULT_OWNER, 500 ether);

        // SmartVaultV4.Status memory status = vault.status();
        // uint256 vaultDebt = status.minted;
        // uint256 vaultTokenID = 1;
        // bytes memory ethUSDsSwapPath =
        //     abi.encodePacked(WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS, RAMSES_FEE, USDS_ADDRESS);
        // uint256 ETHToSell = ethCollateral / 100;
        // vm.prank(VAULT_MANAGER_OWNER);
        // uint256 _USDsRedeemed = smartVaultManager.vaultAutoRedemption(
        //     vaultTokenID, UNISWAP_ROUTER_ADDRESS, address(0), ethUSDsSwapPath, ETHToSell
        // );

        // status = vault.status();
        // assertEq(status.minted, vaultDebt - _USDsRedeemed);
        // assertEq(address(vault).balance, ethCollateral - ETHToSell);
    }
}

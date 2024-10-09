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
        vm.deal(address(vault), 1 ether);

        vm.prank(VAULT_OWNER);
        vault.depositYield(NATIVE, 1e4, 5e4, block.timestamp + 60);

        vm.prank(VAULT_OWNER);
        vault.withdrawYield(address(usdsHypervisor), NATIVE, 5e4, block.timestamp + 60);

        vm.prank(VAULT_OWNER);
        vault.withdrawYield(WBTC_HYPERVISOR_ADDRESS, NATIVE, 5e4, block.timestamp + 60);
    }

    function test_autoRedemption() public {
        // make USDs cheaper, so redemption will be required:
        uint256 usdsDump = 50000 ether;
        usds.approve(UNISWAP_ROUTER_ADDRESS, usdsDump);
        ISwapRouter(UNISWAP_ROUTER_ADDRESS).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(usds),
                tokenOut: USDC_ADDRESS,
                fee: UNISWAP_FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdsDump,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        uint256 ethCollateral = 1 ether;
        vm.deal(address(vault), 1 ether);

        vm.prank(VAULT_OWNER);
        vault.mint(VAULT_OWNER, 500 ether);

        SmartVaultV4.Status memory status = vault.status();
        uint256 vaultDebt = status.minted;
        uint256 vaultTokenID = 1;
        bytes memory ethUSDsSwapPath =
            abi.encodePacked(WETH_ADDRESS, UNISWAP_FEE, USDC_ADDRESS, UNISWAP_FEE, address(usds));
        vm.prank(VAULT_MANAGER_OWNER);
        uint256 ETHToSell = ethCollateral / 100;
        uint256 _USDsRedeemed = smartVaultManager.vaultAutoRedemption(
            vaultTokenID, UNISWAP_ROUTER_ADDRESS, address(0), ethUSDsSwapPath, ETHToSell
        );

        status = vault.status();
        console.log(status.minted);
        assertEq(status.minted, vaultDebt - _USDsRedeemed);
        assertEq(address(vault).balance, ethCollateral - ETHToSell);
    }
}

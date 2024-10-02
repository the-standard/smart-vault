// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./fixtures/ForkFixture.sol";
import {IMerklDistributor} from "src/interfaces/IMerklDistributor.sol";
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

    function test_merklClaim() public {
        IMerklDistributor.claim(
            [address(vault)],
            [0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f],
            [530341091410035713962],
            [
                [
                    0x27be4c16fc0ff808a2cf73270b4833d0608300ca7f38315f765f248cc692235e,
                    0x2d0306dde0b9eb1ea38995e5e1b7079f94140f24dafaf6f4be38cba7ec594edc,
                    0x2ca977fb9ddfa692e461df431a3a5875fd1835780259badc01f9f4bb9184d353,
                    0x184088884f3796f63deefd802faab8e060cbb3aaff7336de8f13519bea1f12ef,
                    0x13f33d807cedbffd68fd533427c11ace8ae240549950502cb87a3bf958c8c8dc,
                    0x6aecf60c5f8d864fde1c362ef940b07116d460d81db69b06617ed594ad39e8fe,
                    0x14aa70ccba58fabda42dd4267218365c23937954a02bc8cce77deefff91e7cf1,
                    0x2632155d4a7e9a2ced8cabcd96777a37e60138df8b55854aa3c3fe926f91dfbc,
                    0x973836a741e23502579c373751728c2c09b52ad284459602d2ba4c1c9d793381,
                    0xcfe63c58196b7e70cb9715d4f0c56919939b07c6173a7fa0837f32e7497444ce,
                    0x424eb21b28c0990d779f3fd400f2a08401f0e2e6362b298cebecef49c6ab0fbb,
                    0x17a1d7bdf8e7b4f69d265f6b76cfb853ab482257b60ad2a6bceb8688796ce625,
                    0xac58d76c746505eec6a8c40db67b934e41807e7355f3f663a191c41aedb158e6,
                    0xb192e40d2dc6a1195c6840616f04caee61ca854ba9dd7a37ce7ef853837cc3ff
                ]
            ]
        );
    }
}

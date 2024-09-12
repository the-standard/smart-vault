// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {ExpectedErrors} from "./ExpectedErrors.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";

abstract contract TargetFunctions is ExpectedErrors {
    // NOTE: see smartVaultManagerV6_liquidateVault below
    // but keep this here in case liquidation logic changes
    // function smartVaultV4_liquidate(uint256 _tokenId)
    //     public
    //     getMsgSender
    //     hasMintedUsds
    //     checkExpectedErrors(LIQUIDATE_VAULT_ERRORS)
    // {
    //     (SmartVaultV4 smartVault, uint256 tokenId) = _getRandomSmartVault(_tokenId);

    //     __before(tokenId);

    //     vm.prank(msgSender);
    //     (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.liquidate, ()));

    //     if (success) {
    //         __after(tokenId);

    //         t(_before.undercollateralised, LIQUIDATE_01);
    //         // TODO: BeforeAfter state variables
    //         // gte(
    //         //     _after.protocol.collateralTokenBalance,
    //         //     _before.protocol.collateralTokenBalance,
    //         //     LIQUIDATE_02
    //         // );
    //         eq(_after.minted, 0, LIQUIDATE_03);
    //         t(_after.liquidated, LIQUIDATE_04);
    //         eq(_after.maxMintable, 0, LIQUIDATE_05);
    //     }
    // }

    // TODO: add a helper to add collateral, or just mint directly to a single smart vault during setup (since borrowing is isolated to a single vault)

    function smartVaultV4_removeCollateralNative(uint256 amount, address payable to, uint256 _tokenId)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        (SmartVaultV4 smartVault, uint256 tokenId) = _getRandomSmartVault(_tokenId);
        
        __before(tokenId);
        uint256 _toBalanceBefore = to.balance;

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateralNative, (amount, to)));

        if (success) {
            __after(tokenId);

            gte(_before.status.totalCollateralValue, _after.status.totalCollateralValue, REMOVE_COLLATERAL_NATIVE_01);
            eq(_before.nativeBalance - amount, _after.nativeBalance, REMOVE_COLLATERAL_NATIVE_02);
            eq(_toBalanceBefore + amount, to.balance, REMOVE_COLLATERAL_NATIVE_03);
        }
    }

    function smartVaultV4_removeCollateral(uint256 symbolIndex, uint256 amount, address to)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        (SmartVaultV4 smartVault, uint256 tokenId) = _getRandomSmartVault(_tokenId);
        (ERC20Mock collateral, bytes32 symbol) = _getRandomCollateral(symbolIndex);
        
        __before(tokenId);
        
        uint256 _toBalanceBefore = collateral.balanceOf(to);

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateral, (symbol, amount, to)));

        if (success) {
            __after(tokenId);

            gte(_before.status.totalCollateralValue, _after.status.totalCollateralValue, REMOVE_COLLATERAL_NATIVE_01);
            for (uint256 i = 0; i < _before.status.collateral.length; i++) {
                if (_before.status.collateral[i].token.symbol == symbol) {
                    eq(
                        _before.status.collateral[i].amount - amount,
                        _after.status.collateral[i].amount,
                        REMOVE_COLLATERAL_NATIVE_02
                    );
                }
            }
            eq(_toBalanceBefore + amount, collateral.balanceOf(to), REMOVE_COLLATERAL_NATIVE_03);
        }
    }

    function smartVaultV4_removeAsset(uint256 symbolIndex, uint256 amount, address to, uint256 tokenId)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        (SmartVaultV4 smartVault, uint256 tokenId) = _getRandomSmartVault(_tokenId);
        (ERC20Mock collateral, bytes32 symbol) = _getRandomCollateral(symbolIndex); // TODO: get random asset (for now just test collateral)

        __before(tokenId);

        uint256 _toBalanceBefore = collateral.balanceOf(to);

        vm.prank(msgSender);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.removeAsset, (token, amount, to)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_mint(address to, uint256 amount) public getMsgSender checkExpectedErrors(MINT_DEBT_ERRORS) {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.mint, (to, amount)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_burn(uint256 amount) public getMsgSender checkExpectedErrors(BURN_DEBT_ERRORS) {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.burn, amount));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_swap(bytes32 inToken, bytes32 outToken, uint256 amount, uint256 requestedMinOut)
        public
        getMsgSender
        checkExpectedErrors(SWAP_COLLATERAL_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.swap, (inToken, outToken, amount, requestedMinOut)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_depositYield(bytes32 symbol, uint256 stablePercentage)
        public
        getMsgSender
        checkExpectedErrors(DEPOSIT_YIELD_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.depositYield, (symbol, stablePercentage)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_withdrawYield(address hypervisor, bytes32 symbol)
        public
        getMsgSender
        checkExpectedErrors(WITHDRAW_YIELD_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.withdrawYield, (hypervisor, symbol)));

        if (success) {
            __after();
        }
    }

    // SmartVaultV4 view functions: status, undercollateralised, getToken, getTokenisedAddr, calculateMinimumAmountOut, yieldAssets

    function smartVaultYieldManager_deposit(address token, uint256 usdPercentage)
        public
        getMsgSender
        checkExpectedErrors(DEPOSIT_YIELD_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(yieldManager).call(abi.encodeCall(yieldManager.deposit, (token, usdPercentage)));

        if (success) {
            __after();
        }
    }

    function smartVaultYieldManager_withdraw(address hypervisor, address token)
        public
        getMsgSender
        checkExpectedErrors(WITHDRAW_YIELD_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(yieldManager).call(abi.encodeCall(yieldManager.withdraw, (hypervisor, token)));

        if (success) {
            __after();
        }
    }

    function smartVaultManagerV6_liquidateVault(uint256 _tokenId)
        public
        getMsgSender
        checkExpectedErrors(LIQUIDATE_VAULT_ERRORS)
    {
        (SmartVaultV4 smartVault, uint256 tokenId) = _getRandomSmartVault(_tokenId);

        __before(tokenId);

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVaultManager).call(abi.encodeCall(smartVaultManager.liquidateVault, tokenId));

        if (success) {
            __after(tokenId);

            t(_before.undercollateralised, LIQUIDATE_01);
            // TODO: BeforeAfter state variables
            // gte(
            //     _after.protocol.collateralTokenBalance,
            //     _before.protocol.collateralTokenBalance,
            //     LIQUIDATE_02
            // );
            eq(_after.minted, 0, LIQUIDATE_03);
            t(_after.liquidated, LIQUIDATE_04);
            eq(_after.maxMintable, 0, LIQUIDATE_05);
        }
    }
}

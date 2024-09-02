// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {ExpectedErrors} from "./ExpectedErrors.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";

abstract contract TargetFunctions is ExpectedErrors {
    function smartVaultV4_liquidate() public getMsgSender checkExpectedErrors(LIQUIDATE_VAULT_ERRORS) {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.liquidate, ())); // TODO: smart vaults setup and get random vault helper

        if (success) {
            __after();
        }
    }

    function smartVaultV4_removeCollateralNative(uint256 amount, address payable to)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateralNative, (amount, to)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_removeCollateral(bytes32 symbol, uint256 amount, address to)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateral, (symbol, amount, to)));

        if (success) {
            __after();
        }
    }

    function smartVaultV4_removeAsset(address token, uint256 amount, address to)
        public
        getMsgSender
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

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

    function smartVaultManagerV6_liquidateVault(uint256 tokenId)
        public
        getMsgSender
        checkExpectedErrors(LIQUIDATE_VAULT_ERRORS)
    {
        __before();

        SmartVaultV4 smartVault = _getRandomSmartVault();

        vm.prank(msgSender);
        (success, returnData) =
            address(smartVaultManager).call(abi.encodeCall(smartVaultManager.liquidateVault, tokenId));

        if (success) {
            __after();
        }
    }
}

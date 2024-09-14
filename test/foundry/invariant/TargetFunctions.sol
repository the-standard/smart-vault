// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {ExpectedErrors} from "./ExpectedErrors.sol";
import {Properties} from "./Properties.sol";
import {vm} from "@chimera/Hevm.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

abstract contract TargetFunctions is ExpectedErrors {
    // NOTE: see smartVaultManagerV6_liquidateVault below but keep this here in case liquidation logic changes (spoiler: it does)
    // function smartVaultV4_liquidate(uint256 tokenId) public checkExpectedErrors(LIQUIDATE_VAULT_ERRORS) {}

    // TODO: use fork fixture and implement hypervisor handlers

    function helper_addSmartVaultCollateral(uint256 symbolIndex, uint256 amount) public {
        (ERC20Mock collateral, bytes32 symbol) = _getRandomCollateral(symbolIndex);

        if (symbol == NATIVE) {
            amount = between(amount, 0, 10 ether); // TODO: bound here and other amounts based on initial balances in Common setup
            vm.deal(address(smartVault), amount);
        } else {
            amount = between(amount, 0, type(uint96).max);
            collateral.mint(address(smartVault), amount);
        }
    }

    function helper_setPrice(int256 price, uint256 index) public clear {
        // TODO: implement per-feed min/max
        // (ChainlinkMock priceFeed, uint256 min, uint256 max) = _getRandomPriceFeed(index);
        ChainlinkMock priceFeed = _getRandomPriceFeed(index);
        priceFeed.setPrice(between(price, DEFAULT_CL_MIN, DEFAULT_CL_MAX));
    }

    function smartVaultV4_removeCollateralNative(uint256 amount, address payable to)
        public
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        
        __before(smartVault);

        amount = between(amount, 0, address(smartVault).balance);
        uint256 _toBalanceBefore = to.balance;

        vm.prank(VAULT_OWNER);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateralNative, (amount, to)));

        if (success) {
            __after(smartVault);

            gte(_before.totalCollateralValue, _after.totalCollateralValue, REMOVE_COLLATERAL_NATIVE_01);
            eq(_before.nativeBalance - amount, _after.nativeBalance, REMOVE_COLLATERAL_NATIVE_02);
            eq(_toBalanceBefore + amount, to.balance, REMOVE_COLLATERAL_NATIVE_03);
        }
    }

    function smartVaultV4_removeCollateral(uint256 symbolIndex, uint256 amount, address to)
        public
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {
        (ERC20Mock collateral, bytes32 symbol) = _getRandomCollateral(symbolIndex);
        
        bool isNative = symbol == NATIVE;
        uint256 _toBalanceBefore;
        
        __before(smartVault);
        
        if (isNative) {
            amount = between(amount, 0, address(smartVault).balance);
            _toBalanceBefore = to.balance;
        } else {
            amount = between(amount, 0, collateral.balanceOf(address(smartVault)));
            _toBalanceBefore = collateral.balanceOf(to);
        }

        vm.prank(VAULT_OWNER);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.removeCollateral, (symbol, amount, to)));

        if (success) {
            __after(smartVault);

            gte(_before.totalCollateralValue, _after.totalCollateralValue, REMOVE_COLLATERAL_NATIVE_01);
            // NOTE: these type of properties cannot be easily checked as the Asset[] array cannot be copied from memory to storage
            // for (uint256 i = 0; i < _before.collateral.length; i++) {
            //     if (_before.collateral[i].token.symbol == symbol) {
            //         eq(
            //             _before.collateral[i].amount - amount,
            //             _after.collateral[i].amount,
            //             REMOVE_COLLATERAL_NATIVE_02
            //         );
            //     }
            // }
            if (isNative) {
                eq(_toBalanceBefore + amount, to.balance, REMOVE_COLLATERAL_NATIVE_03);
            } else {
                eq(_toBalanceBefore + amount, collateral.balanceOf(to), REMOVE_COLLATERAL_NATIVE_03);
            }
        }
    }

    function smartVaultV4_removeAsset(uint256 tokenIndex, uint256 amount, address to)
        public
        checkExpectedErrors(REMOVE_VAULT_TOKEN_ERRORS)
    {

        __before(smartVault);

        uint256 _toBalanceBefore;

        ERC20 asset = ERC20(_getRandomToken(tokenIndex));
        bool isNative = address(asset) == address(0);
        if (isNative) {
            amount = between(amount, 0, address(smartVault).balance);
            _toBalanceBefore = to.balance;
        } else {
            amount = between(amount, 0, asset.balanceOf(address(smartVault)));
            _toBalanceBefore = asset.balanceOf(to);
        }

        vm.prank(VAULT_OWNER);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.removeAsset, (address(asset), amount, to)));

        if (success) {
            __after(smartVault);

            if (_collateralContains(address(asset))) {
                gte(_before.totalCollateralValue, _after.totalCollateralValue, REMOVE_ASSET_01);
                // for (uint256 i = 0; i < _before.collateral.length; i++) {
                //     if (_before.collateral[i].token.symbol == symbol) {
                //         eq(
                //             _before.collateral[i].amount - amount,
                //             _after.collateral[i].amount,
                //             REMOVE_ASSET_02
                //         );
                //     }
                // }
                if (isNative) {
                    eq(_toBalanceBefore + amount, to.balance, REMOVE_ASSET_03);
                } else {
                    eq(_toBalanceBefore + amount, asset.balanceOf(to), REMOVE_ASSET_03);
                }
                t(!_after.undercollateralised, REMOVE_ASSET_04);
            } else {
                eq(_before.totalCollateralValue, _after.totalCollateralValue, REMOVE_ASSET_05);
                eq(asset.balanceOf(address(smartVault)), 0, REMOVE_ASSET_06);
                eq(asset.balanceOf(to), amount, REMOVE_ASSET_07);
            }
        }
    }

    function smartVaultV4_mint(address to, uint256 amount) public checkExpectedErrors(MINT_DEBT_ERRORS) {
        amount = between(amount, 0, type(uint96).max);

        __before(smartVault);

        uint256 _toBalanceBefore = usds.balanceOf(to);

        vm.prank(VAULT_OWNER);
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.mint, (to, amount)));

        if (success) {
            __after(smartVault);

            eq(_toBalanceBefore + amount, usds.balanceOf(to), MINT_01);
            gte(_after.minted, _before.minted + amount, MINT_02); // to account for fee
            gte(_before.maxMintable, _after.minted, MINT_03);
            t(!_after.undercollateralised, MINT_04);
        }
    }

    function smartVaultV4_burn(uint256 amount) public checkExpectedErrors(BURN_DEBT_ERRORS) {
        amount = between(amount, 0, type(uint96).max);

        __before(smartVault);

        uint256 _msgSenderBalanceBefore = usds.balanceOf(msgSender);

        vm.prank(VAULT_OWNER); // NOTE: can be called by any address but prank owner for simplicity
        (success, returnData) = address(smartVault).call(abi.encodeCall(smartVault.burn, amount));

        if (success) {
            __after(smartVault);

            gte(_msgSenderBalanceBefore - amount, usds.balanceOf(msgSender), BURN_01); // to account for fee
            eq(_before.minted - amount, _after.minted, BURN_02);
        }
    }

    function smartVaultV4_swap(uint256 inTokenIndex, uint256 outTokenIndex, uint256 amount, uint256 requestedMinOut)
        public
        checkExpectedErrors(SWAP_COLLATERAL_ERRORS)
    {
        bytes32 inToken = _getRandomSymbol(inTokenIndex);
        bytes32 outToken = _getRandomSymbol(outTokenIndex);
        amount = between(amount, 0, type(uint96).max);
        requestedMinOut = between(requestedMinOut, 0, amount);

        __before(smartVault);

        vm.prank(VAULT_OWNER);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.swap, (inToken, outToken, amount, requestedMinOut)));

        if (success) {
            __after(smartVault);

            t(!_after.undercollateralised, SWAP_01);
            gte(_before.totalCollateralValue, _after.totalCollateralValue, SWAP_02);
            // for (uint256 i = 0; i < _before.collateral.length; i++) {
            //     if (_before.collateral[i].token.symbol == inToken) {
            //         eq(
            //             _before.collateral[i].amount - amount,
            //             _after.collateral[i].amount,
            //             SWAP_03
            //         );
            //     }

            //     if (_before.collateral[i].token.symbol == outToken) {
            //         eq(
            //             _before.collateral[i].amount + requestedMinOut,
            //             _after.collateral[i].amount,
            //             SWAP_04
            //         );
            //     }
            // }
        }
    }

    function smartVaultV4_depositYield(uint256 symbolIndex, uint256 stablePercentage)
        public
        checkExpectedErrors(DEPOSIT_YIELD_ERRORS)
    {
        (, bytes32 symbol) = _getRandomCollateral(symbolIndex);
        stablePercentage = between(stablePercentage, MIN_STABLE_PERCENTAGE, MAX_STABLE_PERCENTAGE);

        __before(smartVault);

        vm.prank(VAULT_OWNER);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.depositYield, (symbol, stablePercentage)));

        if (success) {
            __after(smartVault);
            _addHypervisor(address(collateralData[symbol].hypervisor));

            t(!_after.undercollateralised, DEPOSIT_YIELD_01);
        }
    }

    function smartVaultV4_withdrawYield(uint256 hypervisorIndex, uint256 symbolIndex)
        public
        checkExpectedErrors(WITHDRAW_YIELD_ERRORS)
    {
        (, bytes32 symbol) = _getRandomCollateral(symbolIndex);
        address hypervisor = _getRandomHypervisor(hypervisorIndex);

        if(hypervisor == address(0)) {
            return;
        }

        __before(smartVault);

        vm.prank(VAULT_OWNER);
        (success, returnData) =
            address(smartVault).call(abi.encodeCall(smartVault.withdrawYield, (hypervisor, symbol)));

        if (success) {
            __after(smartVault);
            _removeHypervisor(hypervisor);

            t(!_after.undercollateralised, WITHDRAW_YIELD_01);
        }
    }

    // SmartVaultV4 view functions: status, undercollateralised, getToken, getTokenisedAddr, calculateMinimumAmountOut, yieldAssets

    // NOTE: these probably aren't needed as they essentially just call Hypervisor functions the long way round
    // function smartVaultYieldManager_deposit(address token, uint256 usdPercentage) public checkExpectedErrors(DEPOSIT_YIELD_ERRORS) {}
    // function smartVaultYieldManager_withdraw(address hypervisor, address token) public checkExpectedErrors(WITHDRAW_YIELD_ERRORS) {}

    function smartVaultManagerV6_liquidateVault()
        public
        checkExpectedErrors(LIQUIDATE_VAULT_ERRORS)
    {
        // NOTE: this is a bit hacky – we should get/store the token id in the setup
        uint256[] memory tokenIds = smartVaultIndex.getTokenIds(VAULT_OWNER);

        __before(smartVault);

        vm.prank(LIQUIDATOR);
        (success, returnData) =
            address(smartVaultManager).call(abi.encodeCall(smartVaultManager.liquidateVault, tokenIds[0]));

        if (success) {
            __after(smartVault);

            t(_before.undercollateralised, LIQUIDATE_01);
            // for (uint256 i = 0; i < _before.collateral.length; i++) {
            //     gte(
            //         _after.protocol.collateral[i].amount,
            //         _before.protocol.collateral[i].amount,
            //         LIQUIDATE_02
            //     );
            // }
            eq(_after.minted, 0, LIQUIDATE_03);
            t(_after.liquidated, LIQUIDATE_04);
            eq(_after.maxMintable, 0, LIQUIDATE_05);
            eq(_after.totalCollateralValue, 0, LIQUIDATE_06);
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {SmartVaultManagerFixture, SmartVaultManagerV6} from "./fixtures/SmartVaultManagerFixture.sol";
import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {ISmartVault} from "src/interfaces/ISmartVault.sol";

contract SmartVaultManagerTest is SmartVaultManagerFixture, Test {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event VaultDeployed(address indexed vaultAddress, address indexed owner, address vaultType, uint256 tokenId);
    event VaultLiquidated(address indexed vaultAddress);
    event VaultTransferred(uint256 indexed tokenId, address from, address to);

    function setUp() public override {
        super.setUp();
    }

    function test_openVault() public {
        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(false, true, false, true);
        emit VaultDeployed(address(0), VAULT_OWNER, address(usds), smartVaultManager.totalSupply() + 1);
        (address vault, uint256 tokenId) = smartVaultManager.mint();
        vm.stopPrank();

        assertEq(smartVaultManager.totalSupply(), 1);
        assertEq(smartVaultManager.balanceOf(VAULT_OWNER), 1);
        assertEq(smartVaultManager.vaultIDs(VAULT_OWNER).length, 1);

        ISmartVault.Status memory status = smartVaultManager.vaultData(tokenId).status;
        assertEq(status.vaultAddress, vault);
        assertEq(status.minted, 0);
        assertEq(status.maxMintable, 0);
        assertEq(status.totalCollateralValue, 0);
        assertEq(status.collateral.length, collateralSymbols.length()); // collateralSymbols.length - 1 + NATIVE
        assertEq(status.liquidated, false);
        assertEq(status.version, 4);
        assertEq(status.vaultType, bytes32("USDs"));

        assertEq(smartVaultManager.collateralRate(), COLLATERAL_RATE);
        assertEq(smartVaultManager.mintFeeRate(), PROTOCOL_FEE_RATE);
        assertEq(smartVaultManager.burnFeeRate(), PROTOCOL_FEE_RATE);
    }

    function test_vaultLimit() public {
        vm.startPrank(VAULT_OWNER);
        for (uint256 i = 0; i < VAULT_LIMIT; i++) {
            smartVaultManager.mint();
        }
        vm.expectRevert("err-vault-limit");
        smartVaultManager.mint();
    }

    function test_liquidateVault() public {
        vm.prank(VAULT_OWNER);
        (address vault, uint256 tokenId) = smartVaultManager.mint();

        // liquidator balances before
        address liquidator = makeAddr("liquidator");

        uint256 liquidatorETHBalance = liquidator.balance;
        uint256 liquidatorWETHBalance = weth.balanceOf(liquidator);

        assertEq(liquidatorETHBalance, 0);
        assertEq(liquidatorWETHBalance, 0);

        // Mint collateral to the vault
        uint256 wethAmount = 1 ether;
        weth.mint(vault, wethAmount);

        uint256 nativeAmount = 1 ether;
        (bool success,) = vault.call{value: nativeAmount}("");
        if (!success) {
            console.log("Failed to mint native collateral");
        }

        // Mint 99% of the max mintable amount
        ISmartVault.Status memory statusBefore = smartVaultManager.vaultData(tokenId).status;
        assertTrue(statusBefore.maxMintable > 0);
        uint256 mintValue = statusBefore.maxMintable * 99 / 100;

        vm.prank(VAULT_OWNER);
        SmartVaultV4(payable(vault)).mint(VAULT_OWNER, mintValue);

        vm.prank(liquidator);
        // Attempt to liquidate without USDs to burn
        vm.expectRevert("ERC20: burn amount exceeds balance");
        smartVaultManager.liquidateVault(tokenId);

        // mint extra because of outstanding fees in vault debt
        usds.mint(liquidator, mintValue * 2);

        // Attempt to liquidate with valid liquidator
        vm.prank(liquidator);
        vm.expectRevert(SmartVaultV4.NotUndercollateralised.selector);
        smartVaultManager.liquidateVault(tokenId);

        // Drop the price of ETH to $1000
        clNativeUsd.setPrice(1000_0000_0000);

        // Liquidate undercollateralized vault
        vm.prank(liquidator);
        vm.expectEmit(true, false, false, false);
        emit VaultLiquidated(vault);
        smartVaultManager.liquidateVault(tokenId);

        // Assert vault is liquidated
        ISmartVault.Status memory statusAfter = smartVaultManager.vaultData(tokenId).status;
        assertEq(statusAfter.liquidated, true);
        assertEq(statusAfter.minted, 0);
        assertEq(statusAfter.maxMintable, 0);
        assertEq(statusAfter.totalCollateralValue, 0);
        assertEq(statusAfter.collateral.length, collateralSymbols.length()); // collateralSymbols.length - 1 + NATIVE
        for (uint256 i = 0; i < statusAfter.collateral.length; i++) {
            assertEq(statusAfter.collateral[i].amount, 0);
        }

        // Assert liquidator balances
        assertEq(weth.balanceOf(liquidator), liquidatorWETHBalance + wethAmount);
        assertEq(liquidator.balance, liquidatorETHBalance + nativeAmount);
    }

    function test_transferVault() public {
        // Mint two vaults as VAULT_OWNER
        vm.startPrank(VAULT_OWNER);
        (address vault, uint256 tokenId) = smartVaultManager.mint();
        smartVaultManager.mint();
        vm.stopPrank();

        uint256 senderBalanceBefore = smartVaultManager.balanceOf(VAULT_OWNER);
        assertEq(senderBalanceBefore, 2);
        assertEq(smartVaultManager.vaultIDs(VAULT_OWNER).length, senderBalanceBefore);

        // Mint a vault as recipient
        address recipient = makeAddr("Recipient");
        vm.prank(recipient);
        smartVaultManager.mint();

        uint256 recipientBalanceBefore = smartVaultManager.balanceOf(recipient);
        assertEq(smartVaultManager.balanceOf(recipient), 1);
        assertEq(smartVaultManager.vaultIDs(recipient).length, recipientBalanceBefore);

        // Attempt to transfer with invalid recipient invalid caller
        vm.expectRevert("ERC721: caller is not token owner or approved");
        smartVaultManager.transferFrom(VAULT_OWNER, address(0), tokenId);

        // Attempt to transfer with invalid recipient
        vm.startPrank(VAULT_OWNER);
        vm.expectRevert("ERC721: transfer to the zero address");
        smartVaultManager.transferFrom(VAULT_OWNER, address(0), tokenId);
        vm.stopPrank();

        // Transfer the vault
        assertEq(SmartVaultV4(payable(vault)).owner(), VAULT_OWNER);

        vm.startPrank(VAULT_OWNER);
        vm.expectEmit(true, false, false, true);
        emit VaultTransferred(tokenId, VAULT_OWNER, recipient);
        smartVaultManager.transferFrom(VAULT_OWNER, recipient, tokenId);
        vm.stopPrank();

        // Assert vault ownership
        assertEq(SmartVaultV4(payable(vault)).owner(), recipient);
        assertEq(smartVaultManager.ownerOf(tokenId), recipient);

        assertEq(smartVaultManager.balanceOf(VAULT_OWNER), senderBalanceBefore - 1);
        assertEq(smartVaultManager.vaultIDs(VAULT_OWNER).length, senderBalanceBefore - 1);

        assertEq(smartVaultManager.balanceOf(recipient), recipientBalanceBefore + 1);
        assertEq(smartVaultManager.vaultIDs(recipient).length, recipientBalanceBefore + 1);

        bool found;
        uint256[] memory recipientIds = smartVaultManager.vaultIDs(recipient);
        for (uint256 i = 0; i < recipientIds.length; i++) {
            for (uint256 i = 0; i < recipientIds.length; i++) {
                if (recipientIds[i] == tokenId) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }
    }

    function test_nftMetadata() public {
        vm.prank(VAULT_OWNER);
        (address vault, uint256 tokenId) = smartVaultManager.mint();
        string memory metadataJSON = smartVaultManager.tokenURI(tokenId);

        // Compare the first 28 characters of metadataJSON with the expected string
        bytes memory metadataBytes = bytes(metadataJSON);
        bytes memory expectedPrefix = bytes("data:application/json;base64,");

        assertTrue(metadataBytes.length >= expectedPrefix.length);
        // Compare each byte to ensure the prefix matches
        for (uint256 i = 0; i < expectedPrefix.length; i++) {
            assertEq(metadataBytes[i], expectedPrefix[i], "Prefix does not match expected value");
        }
    }
}

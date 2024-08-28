// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@chimera/Hevm.sol";

import {SmartVaultManagerFixture} from "./SmartVaultManagerFixture.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";

contract SmartVaultFixture is SmartVaultManagerFixture {
    struct VaultData {
        SmartVaultV4 vault;
        uint256 tokenId;
    }

    mapping(address => VaultData[]) smartVaults;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(VAULT_OWNER);
        (address vault, uint256 tokenId) = smartVaultManager.mint();
        smartVaults[VAULT_OWNER].push(VaultData(SmartVaultV4(payable(vault)), tokenId));
    }
}

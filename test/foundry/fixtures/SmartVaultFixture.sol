// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@chimera/Hevm.sol";

import {SmartVaultYieldManagerFixture} from "./SmartVaultYieldManagerFixture.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {PriceCalculator} from "src/PriceCalculator.sol";

contract SmartVaultFixture is SmartVaultYieldManagerFixture {
    struct VaultData {
        SmartVaultV4 vault;
        uint256 tokenId;
    }

    mapping(address => VaultData[]) smartVaults;

    function setUp() public virtual override {
        super.setUp();
    }

    function _createSmartVaultViaManager(address owner) internal returns (SmartVaultV4) {
        vm.prank(owner);
        (address vault, uint256 tokenId) = smartVaultManager.mint();
        smartVaults[owner].push(VaultData(SmartVaultV4(payable(vault)), tokenId));
        return SmartVaultV4(payable(vault));
    }

    function _createStandaloneSmartVault(address owner) internal returns (SmartVaultV4 vault) {
        // NOTE: Smart vault is deployed bypassing the manager, so we need to grant USDs minter/burner roles

        vault = new SmartVaultV4(NATIVE, address(smartVaultManager), owner, address(usds), address(priceCalculator));
        usds.grantRole(usds.MINTER_ROLE(), address(vault));
        usds.grantRole(usds.BURNER_ROLE(), address(vault));
    }

    function _getVaultCollateralVaulue(SmartVaultV4 vault) internal view returns (uint256) {
        return vault.status().totalCollateralValue;
    }
}

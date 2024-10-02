// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {SmartVaultV4, ISmartVault} from "src/SmartVaultV4.sol";

import {Helper} from "./Helper.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Helper {
    struct Vars {
        bytes4 sig;
        uint256 minted;
        uint256 maxMintable;
        uint256 totalCollateralValue;
        bool liquidated;
        bool undercollateralised;
        uint256 nativeBalance;
    }

    Vars internal _before;
    Vars internal _after;

    modifier clear() {
        Vars memory e;
        _before = e;
        _after = e;
        _;
    }

    // NOTE: this is helpful if we are considering only a single SmartVault
    modifier hasMintedUsds() {
        (_before.minted) = smartVault.status().minted;
        precondition(_before.minted > 0);
        _;
    }

    function __snapshot(Vars storage vars, SmartVaultV4 vault) internal {
        vars.sig = msg.sig;
        // NOTE: use vault token ids for multiple SmartVaults
        // SmartVaultV4 vault = _tokenIdToSmartVault(tokenId);
        vars.minted = vault.status().minted;
        vars.maxMintable = vault.status().maxMintable;
        vars.totalCollateralValue = vault.status().totalCollateralValue;
        vars.liquidated = vault.status().liquidated;
        vars.undercollateralised = vault.undercollateralised();
        vars.nativeBalance = address(vault).balance;
    }

    function __before(SmartVaultV4 vault) internal {
        __snapshot(_before, vault);
    }

    function __after(SmartVaultV4 vault) internal {
        __snapshot(_after, vault);
    }
}

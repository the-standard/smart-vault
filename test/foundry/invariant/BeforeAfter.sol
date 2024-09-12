// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {SmartVaultV4, ISmartVault} from "src/SmartVaultV4.sol";

import {Helper} from "./Helper.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Helper {
    struct Vars {
        ISmartVault.Status status;
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
    // which might actually make things easier
    // modifier hasMintedUsds() {
    //     (_before.minted) = smartVault.status().minted;
    //     precondition(_before.minted > 0);
    //     _;
    // }

    function __snapshot(Vars storage vars, uint256 tokenId) internal {
        SmartVaultV4 smartVault = _tokenIdToSmartVault(tokenId);
        vars.status = smartVault.status();

        vars.undercollateralised = smartVault.undercollateralised();
        vars.nativeBalance = address(smartVault).balance;
    }

    function __before(uint256 tokenId) internal {
        __snapshot(_before, tokenId);
    }

    function __after(uint256 tokenId) internal {
        __snapshot(_after, tokenId);
    }
}

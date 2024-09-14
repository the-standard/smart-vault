// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BeforeAfter} from "./BeforeAfter.sol";
import {PropertiesSpecifications} from "./PropertiesSpecifications.sol";
import {ITargetFunctions} from "./interfaces/ITargetFunctions.sol";

// property tests get run after each call in a given sequence
abstract contract Properties is BeforeAfter, PropertiesSpecifications {
    function invariant_UNDERCOLLATERALISED() public returns (bool) {
        if (!_before.undercollateralised && _after.undercollateralised) {
            t(false, UNDERCOLLATERALISED_01);
        }

        return true;
    }
    
    function invariant_FEES() public returns (bool) {
        if (
            _before.sig == ITargetFunctions.smartVaultV4_mint.selector
            || _before.sig == ITargetFunctions.smartVaultV4_burn.selector
            || _before.sig == ITargetFunctions.smartVaultV4_withdrawYield.selector
        ) {
            // TODO: implement ghosts – usds/token balance of protocol after >= before
        }

        return true;
    }
}

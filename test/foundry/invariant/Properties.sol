// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BeforeAfter} from "./BeforeAfter.sol";
import {PropertiesSpecifications} from "./PropertiesSpecifications.sol";

// property tests get run after each call in a given sequence
abstract contract Properties is BeforeAfter, PropertiesSpecifications {
    function invariant_true() public returns (bool) {
        return true;
    }
}

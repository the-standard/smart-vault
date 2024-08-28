// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Helper} from "./Helper.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Helper {
    struct Vars {
        uint256 todo;
    }

    Vars internal _before;
    Vars internal _after;

    modifier clear() {
        Vars memory e;
        _before = e;
        _after = e;
        _;
    }

    function __snapshot(Vars storage vars) internal {}

    function __before() internal {
        __snapshot(_before);
    }

    function __after() internal {
        __snapshot(_after);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FoundryHandler} from "./FoundryHandler.sol";

import {PropertiesSpecifications} from "../PropertiesSpecifications.sol";
import {Test} from "forge-std/Test.sol";

contract FoundryTester is Test, PropertiesSpecifications {
    FoundryHandler public handler;

    function setUp() public {
        handler = new FoundryHandler();
        targetContract(address(handler));
    }

    function invariant() public {
        // assertTrue(handler.invariant_true());
    }
}

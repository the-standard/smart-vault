// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Common} from "./Common.sol";

import {TokenManager} from "src/TokenManager.sol";

contract TokenManagerFixture is Common {
    TokenManager internal tokenManager;

    function setUp() public virtual override {
        super.setUp();

        tokenManager = new TokenManager(NATIVE, address(clNativeUsd));
    }
}

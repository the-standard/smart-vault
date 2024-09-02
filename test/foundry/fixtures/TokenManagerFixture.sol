// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Common} from "./Common.sol";

import {TokenManager} from "src/TokenManager.sol";

contract TokenManagerFixture is Common {
    TokenManager tokenManager;

    function setUp() public virtual override {
        // avoid duplicate invocations by inheriting contracts
        if (collateralSymbols.length == 0) {
            super.setUp();
        }

        tokenManager = new TokenManager(NATIVE, address(clNativeUsd));

        for (uint256 i; i < collateralSymbols.length; i++) {
            if (collateralSymbols[i] == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols[i]];
            tokenManager.addAcceptedToken(address(collateral.token), address(collateral.clFeed));
        }
    }
}

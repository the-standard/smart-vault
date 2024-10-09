// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Common} from "./Common.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {TokenManager} from "src/TokenManager.sol";

contract TokenManagerFixture is Common {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    TokenManager tokenManager;

    function setUp() public virtual override {
        super.setUp();

        tokenManager = new TokenManager(NATIVE, address(clNativeUsd));

        for (uint256 i; i < collateralSymbols.length(); i++) {
            if (collateralSymbols.at(i) == NATIVE) continue;

            CollateralData memory collateral = collateralData[collateralSymbols.at(i)];
            tokenManager.addAcceptedToken(address(collateral.token), address(collateral.clFeed));
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ERC20Mock} from "src/test_utils/ERC20Mock.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

import {TokenManagerFixture, TokenManager} from "./fixtures/TokenManagerFixture.sol";
import {ITokenManager} from "src/interfaces/ITokenManager.sol";

contract TokenManagerTest is TokenManagerFixture, Test {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event TokenAdded(bytes32 symbol, address token);
    event TokenRemoved(bytes32 symbol);

    function setUp() public override {
        super.setUp();
    }

    function test_getInvalidToken() public {
        vm.expectRevert("err-invalid-token");
        tokenManager.getToken(bytes32(bytes("INVALID")));
    }

    function test_defaultNative() public {
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        assertEq(acceptedTokens.length, collateralSymbols.length()); // collateralSymbols.length - 1 + NATIVE

        ITokenManager.Token memory token = acceptedTokens[0];
        assertEq(token.symbol, NATIVE);
        assertEq(token.addr, address(0));
        assertEq(token.clAddr, address(clNativeUsd));
        assertEq(token.clDec, clNativeUsd.decimals());
    }

    function test_manageAcceptedTokens() public {
        ITokenManager.Token[] memory tokensBefore = tokenManager.getAcceptedTokens();
        assertEq(tokensBefore.length, collateralSymbols.length()); // collateralSymbols.length - 1 + NATIVE

        // native cannot be removed
        vm.expectRevert("err-native-required");
        tokenManager.removeAcceptedToken(NATIVE);

        // weth can be removed
        bytes32 wethSymbol = bytes32(bytes(weth.symbol()));
        tokenManager.removeAcceptedToken(wethSymbol);
        emit TokenRemoved(wethSymbol);

        ITokenManager.Token[] memory tokensAfter = tokenManager.getAcceptedTokens();
        assertEq(tokensAfter.length, tokensBefore.length - 1);

        // add new token
        string memory newSymbol = "NEW";
        address newToken = address(new ERC20Mock("New Token", newSymbol, 18));
        address clNewUsd = address(new ChainlinkMock("NEW/USD"));

        vm.expectEmit(false, false, false, true);
        emit TokenAdded(bytes32(bytes(newSymbol)), newToken);
        tokenManager.addAcceptedToken(newToken, clNewUsd);

        // cannot add existing token
        vm.expectRevert(abi.encodeWithSelector(TokenManager.TokenExists.selector, bytes32(bytes(newSymbol)), newToken));
        tokenManager.addAcceptedToken(newToken, clNewUsd);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {TokenManagerFixture, TokenManager} from "./fixtures/TokenManagerFixture.sol";
import {ITokenManager} from "src/interfaces/ITokenManager.sol";

contract TokenManagerTest is TokenManagerFixture {
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
        assertEq(acceptedTokens.length, 1);
        
        ITokenManager.Token memory token = acceptedTokens[0];
        assertEq(token.symbol, NATIVE);
        assertEq(token.addr, address(0));
        assertEq(token.clAddr, address(clNativeUsd));
        assertEq(token.clDec, clNativeUsd.decimals());
    }

    function test_manageAcceptedTokens() public {
        bytes32 wethSymbol = bytes32(bytes(weth.symbol()));

        vm.expectEmit(false, false, false, true);
        emit TokenAdded(wethSymbol, address(weth));
        tokenManager.addAcceptedToken(address(weth), address(clNativeUsd));

        vm.expectRevert(abi.encodeWithSelector(TokenManager.TokenExists.selector, wethSymbol, address(weth)));
        tokenManager.addAcceptedToken(address(weth), address(clNativeUsd));

        ITokenManager.Token[] memory tokensBefore = tokenManager.getAcceptedTokens();
        assertEq(tokensBefore.length, 2);

        ITokenManager.Token memory token = tokensBefore[1];
        assertEq(token.symbol, wethSymbol);
        assertEq(token.addr, address(weth));
        assertEq(token.dec, weth.decimals());
        assertEq(token.clAddr, address(clNativeUsd));
        assertEq(token.clDec, clNativeUsd.decimals());

        vm.expectRevert("err-native-required");
        tokenManager.removeAcceptedToken(NATIVE);

        tokenManager.removeAcceptedToken(wethSymbol);
        emit TokenRemoved(wethSymbol);

        ITokenManager.Token[] memory tokensAfter = tokenManager.getAcceptedTokens();
        assertEq(tokensAfter.length, 1);
    }
}

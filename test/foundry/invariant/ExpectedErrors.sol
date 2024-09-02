// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Properties} from "./Properties.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SmartVaultV4} from "src/SmartVaultV4.sol";
import {SmartVaultYieldManager} from "src/SmartVaultYieldManager.sol";

abstract contract ExpectedErrors is Properties {
    bool internal success;
    bytes internal returnData;

    bytes4[] internal LIQUIDATE_VAULT_ERRORS;
    bytes4[] internal REMOVE_VAULT_TOKEN_ERRORS;
    bytes4[] internal MINT_DEBT_ERRORS;
    bytes4[] internal BURN_DEBT_ERRORS;
    bytes4[] internal SWAP_COLLATERAL_ERRORS;
    bytes4[] internal DEPOSIT_YIELD_ERRORS;
    bytes4[] internal WITHDRAW_YIELD_ERRORS;
    bytes4[] internal EMPTY_ERRORS;

    constructor() {
        // LIQUIDATE_VAULT_ERRORS
        LIQUIDATE_VAULT_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        LIQUIDATE_VAULT_ERRORS.push(SmartVaultV4.NotUndercollateralised.selector);
        LIQUIDATE_VAULT_ERRORS.push(SmartVaultV4.TransferError.selector);
        LIQUIDATE_VAULT_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: low-level call failed"))));
        LIQUIDATE_VAULT_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: ERC20 operation did not succeed"))));
        LIQUIDATE_VAULT_ERRORS.push(bytes4(keccak256(bytes("err-invalid-liquidator"))));
        LIQUIDATE_VAULT_ERRORS.push(bytes4(keccak256(bytes("vault-not-undercollateralised"))));
        LIQUIDATE_VAULT_ERRORS.push(bytes4(keccak256(bytes("other-liquidation-error"))));

        // REMOVE_VAULT_TOKEN_ERRORS
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.TransferError.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: low-level call failed"))));
        REMOVE_VAULT_TOKEN_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: ERC20 operation did not succeed"))));

        // MINT_DEBT_ERRORS
        MINT_DEBT_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        MINT_DEBT_ERRORS.push(SmartVaultV4.VaultLiquidated.selector);
        MINT_DEBT_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        // missing AccessControl role dynamic string

        // BURN_DEBT_ERRORS
        BURN_DEBT_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        BURN_DEBT_ERRORS.push(SmartVaultV4.Overrepay.selector);
        // missing AccessControl role dynamic string

        // SWAP_COLLATERAL_ERRORS
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.TransferError.selector);
        SWAP_COLLATERAL_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: low-level call failed"))));
        SWAP_COLLATERAL_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: ERC20 operation did not succeed"))));
        SWAP_COLLATERAL_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: approve from non-zero to non-zero allowance"))));

        // DEPOSIT_YIELD_ERRORS
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        DEPOSIT_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: low-level call failed"))));
        DEPOSIT_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: ERC20 operation did not succeed"))));
        DEPOSIT_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: approve from non-zero to non-zero allowance"))));
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.StablePoolPercentageError.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.HypervisorDataError.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.RatioError.selector);

        // WITHDRAW_YIELD_ERRORS
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        WITHDRAW_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: low-level call failed"))));
        WITHDRAW_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: ERC20 operation did not succeed"))));
        WITHDRAW_YIELD_ERRORS.push(bytes4(keccak256(bytes("SafeERC20: approve from non-zero to non-zero allowance"))));
        WITHDRAW_YIELD_ERRORS.push(SmartVaultYieldManager.IncompatibleHypervisor.selector);
    }

    modifier checkExpectedErrors(bytes4[] storage errors) {
        success = false;
        returnData = bytes("");

        _;

        if (!success) {
            bool expected = false;
            for (uint256 i = 0; i < errors.length; i++) {
                if (_checkReturnData(errors[i], returnData)) {
                    expected = true;
                    break;
                }
            }
            t(expected, DOS);
            precondition(false);
        }
    }

    function _checkReturnData(bytes4 errorSelector, bytes memory returndata) internal view returns (bool reverted) {
        if (returndata.length == 0) reverted = false;

        if (errorSelector == bytes4(returnData)) reverted = true;

        string memory errorString;
        assembly {
            // Get the length of the returndata
            let returndata_size := mload(returndata)

            // The first 32 bytes contain the length of the returndata
            let offset := add(returndata, 0x20)

            // The first 4 bytes of returndata after the length are the function selector (0x08c379a0 for Error(string))
            let selector := mload(offset)

            // Right shift the loaded value by 224 bits to keep only the first 4 bytes (function selector)
            selector := shr(224, selector)

            // Check that the selector matches the expected value for Error(string)
            if eq(selector, 0x08c379a0) {
                // The actual string data starts 32 bytes after the selector
                let stringOffset := add(offset, 0x20)

                // The length of the string is stored at stringOffset
                let stringLength := mload(stringOffset)

                // The actual string data starts 32 bytes after the string length
                let stringData := add(stringOffset, 0x20)

                // Set the length of the string in the allocated memory
                mstore(errorString, stringLength)

                // Copy the string data into the allocated memory
                let dest := add(errorString, 0x20) // point to where string data starts
                for { let i := 0 } lt(i, stringLength) { i := add(i, 0x20) } {
                    mstore(add(dest, i), mload(add(stringData, i)))
                }
            }
        }

        if (errorSelector == bytes4(keccak256(bytes(errorString)))) {
            reverted = true;
        }
    }
}

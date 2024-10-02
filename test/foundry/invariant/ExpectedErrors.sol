// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Properties} from "./Properties.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {stdError} from "forge-std/StdError.sol";

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
        LIQUIDATE_VAULT_ERRORS.push(_encodeError("SafeERC20: low-level call failed"));
        LIQUIDATE_VAULT_ERRORS.push(_encodeError("SafeERC20: ERC20 operation did not succeed"));
        LIQUIDATE_VAULT_ERRORS.push(_encodeError("err-invalid-liquidator"));
        LIQUIDATE_VAULT_ERRORS.push(_encodeError("vault-not-undercollateralised"));
        LIQUIDATE_VAULT_ERRORS.push(_encodeError("other-liquidation-error"));

        // REMOVE_VAULT_TOKEN_ERRORS
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(SmartVaultV4.TransferError.selector);
        REMOVE_VAULT_TOKEN_ERRORS.push(_encodeError("SafeERC20: low-level call failed"));
        REMOVE_VAULT_TOKEN_ERRORS.push(_encodeError("SafeERC20: ERC20 operation did not succeed"));
        REMOVE_VAULT_TOKEN_ERRORS.push(_encodeError("Address: call to non-contract"));

        // MINT_DEBT_ERRORS
        MINT_DEBT_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        MINT_DEBT_ERRORS.push(SmartVaultV4.VaultLiquidated.selector);
        MINT_DEBT_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        MINT_DEBT_ERRORS.push(_encodeError("ERC20: mint to the zero address"));

        // BURN_DEBT_ERRORS
        BURN_DEBT_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        BURN_DEBT_ERRORS.push(SmartVaultV4.Overrepay.selector);
        BURN_DEBT_ERRORS.push(_encodeError("ERC20: burn amount exceeds balance"));

        // SWAP_COLLATERAL_ERRORS
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        SWAP_COLLATERAL_ERRORS.push(SmartVaultV4.TransferError.selector);
        SWAP_COLLATERAL_ERRORS.push(_encodeError("SafeERC20: low-level call failed"));
        SWAP_COLLATERAL_ERRORS.push(_encodeError("SafeERC20: ERC20 operation did not succeed"));
        SWAP_COLLATERAL_ERRORS.push(_encodeError("SafeERC20: approve from non-zero to non-zero allowance"));
        SWAP_COLLATERAL_ERRORS.push(bytes4(keccak256(stdError.arithmeticError)));
        SWAP_COLLATERAL_ERRORS.push(_encodeError(""));

        // DEPOSIT_YIELD_ERRORS
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        DEPOSIT_YIELD_ERRORS.push(_encodeError("SafeERC20: low-level call failed"));
        DEPOSIT_YIELD_ERRORS.push(_encodeError("SafeERC20: ERC20 operation did not succeed"));
        DEPOSIT_YIELD_ERRORS.push(_encodeError("SafeERC20: approve from non-zero to non-zero allowance"));
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.StablePoolPercentageError.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.HypervisorDataError.selector);
        DEPOSIT_YIELD_ERRORS.push(SmartVaultYieldManager.RatioError.selector);
        DEPOSIT_YIELD_ERRORS.push(bytes4(keccak256(stdError.arithmeticError)));
        DEPOSIT_YIELD_ERRORS.push(_encodeError(""));

        // WITHDRAW_YIELD_ERRORS
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.InvalidUser.selector);
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.InvalidToken.selector);
        WITHDRAW_YIELD_ERRORS.push(SmartVaultV4.Undercollateralised.selector);
        WITHDRAW_YIELD_ERRORS.push(_encodeError("SafeERC20: low-level call failed"));
        WITHDRAW_YIELD_ERRORS.push(_encodeError("SafeERC20: ERC20 operation did not succeed"));
        WITHDRAW_YIELD_ERRORS.push(_encodeError("SafeERC20: approve from non-zero to non-zero allowance"));
        WITHDRAW_YIELD_ERRORS.push(SmartVaultYieldManager.IncompatibleHypervisor.selector);
        WITHDRAW_YIELD_ERRORS.push(bytes4(keccak256(stdError.arithmeticError)));
        WITHDRAW_YIELD_ERRORS.push(_encodeError(""));
    }

    function _encodeError(string memory errorString) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodeWithSignature("Error(string)", errorString)));
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
        // Check for Success case
        if (returndata.length == 0) reverted = false;

        // Check for Custom Error case
        if (errorSelector == bytes4(returnData)) reverted = true;

        // Combined Error(string) and Panic(uint256) handling
        string memory errorString;
        uint256 errorCode;
        assembly {
            // Get the length of the returndata
            let returndata_size := mload(returndata)

            // The first 32 bytes contain the length of the returndata
            let offset := add(returndata, 0x20)

            // The first 4 bytes of returndata after the length are the function selector
            let selector := mload(offset)

            // Right shift the loaded value by 224 bits to keep only the first 4 bytes (function selector)
            selector := shr(224, selector)

            switch selector
            case 0x08c379a0 {
                // Error(string)
                // Read the offset to the string (should be 0x20)
                let stringOffset := mload(add(offset, 0x04))

                // Read the length of the string
                let stringLength := mload(add(offset, add(0x04, stringOffset)))

                // Check if the string length is 0 (empty string case)
                switch iszero(stringLength)
                case 1 {
                    // If string is empty, set the memory for errorString to zero length
                    mstore(errorString, 0)
                }
                default {
                    // If string is not empty, copy string data to errorString memory
                    // Allocate memory for the string
                    errorString := mload(0x40)
                    mstore(0x40, add(errorString, add(stringLength, 0x20))) // Allocate memory

                    // Set the length of the string
                    mstore(errorString, stringLength)

                    // Copy the string data to allocated memory
                    let stringData := add(add(offset, 0x24), stringOffset) // Start of string data
                    let dest := add(errorString, 0x20) // point to where string data starts

                    for { let i := 0 } lt(i, stringLength) { i := add(i, 0x20) } {
                        mstore(add(dest, i), mload(add(stringData, i)))
                    }
                }
            }
            case 0x4e487b71 {
                // Panic(uint256)
                // Read the panic code
                errorCode := mload(add(offset, 0x24))
            }
        }

        // Check for Error(string) revert
        if (errorSelector == bytes4(keccak256(abi.encodeWithSignature("Error(string)", errorString)))) {
            reverted = true;
        }

        // Check for Panic(uint256) revert
        if (errorSelector == bytes4(keccak256(abi.encodeWithSignature("Panic(uint256)", errorCode)))) {
            reverted = true;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Bounds {
    uint256 internal MIN_STABLE_PERCENTAGE = 1e4;
    uint256 internal MAX_STABLE_PERCENTAGE = 1e5;
}

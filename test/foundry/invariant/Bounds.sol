// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Bounds {
    uint256 internal constant MIN_STABLE_PERCENTAGE = 1e4;
    uint256 internal constant MAX_STABLE_PERCENTAGE = 1e5;
    int256 internal constant DEFAULT_CL_MIN = 1e5;
    int256 internal constant DEFAULT_CL_MAX = 1e24;
}

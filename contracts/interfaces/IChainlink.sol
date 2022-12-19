// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IChainlink {
    function decimals() external view returns (uint8);

    function latestAnswer() external view returns (int256);
}
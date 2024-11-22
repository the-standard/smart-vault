// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IMerklDistributor {
    function claim(address[] calldata users, address[] calldata tokens, uint256[] calldata amounts, bytes32[][] calldata proofs) external;
}

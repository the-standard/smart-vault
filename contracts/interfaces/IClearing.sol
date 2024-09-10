// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IClearing {
    function owner() external view returns (address);
    function addPosition(address pos, uint8 version) external;
    function setTwapCheck(bool check) external;
}

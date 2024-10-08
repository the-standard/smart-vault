// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISmartVaultDeployer {
    function deploy(address _manager, address _owner, address _usds) external returns (address);
}

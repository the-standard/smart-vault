// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IEUROs is IERC20, IAccessControl {}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUSDs} from "src/interfaces/IUSDs.sol";

interface IAdminUSDs is IUSDs {
    function setSupplyLimit(uint256 _supplyLimit) external;
}

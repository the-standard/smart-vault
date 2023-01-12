// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISEuro is IERC20, IAccessControl {
    function MINTER_ROLE() external returns (bytes32);
    function mint(address to, uint256 amount) external;
}
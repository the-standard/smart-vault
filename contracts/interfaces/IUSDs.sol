// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSDs is IERC20, IAccessControl {
    function MINTER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}

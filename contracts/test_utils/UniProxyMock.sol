// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/IUniProxy.sol";

contract UniProxyMock is IUniProxy {
    mapping(address => mapping(address => uint256)) private ratios;

    function getDepositAmount(address vault, address token, uint256 _deposit)
        external
        view
        returns (uint256 amountStart, uint256 amountEnd)
    {
        uint256 _mid = ratios[vault][token] * _deposit / 1e18;
        return (_mid * 999 / 1000, _mid * 1001 / 1000);
    }

    function deposit(uint256 deposit0, uint256 deposit1, address to, address vault, uint256[4] memory minIn)
        external
        returns (uint256 shares)
    {
        IHypervisor(vault).deposit(deposit0, deposit1, to, msg.sender, minIn);
    }

    function setRatio(address _vault, address _inToken, uint256 _ratio) external {
        ratios[_vault][_inToken] = _ratio;
    }
}

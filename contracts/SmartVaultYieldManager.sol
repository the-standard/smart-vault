// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/IWETH.sol";

contract SmartVaultYieldManager is ISmartVaultYieldManager {

    mapping(bytes32 => address) private vaults;
    address private eurosVault;

    function swap(bytes32 _collateralSymbol, address _tokenOut, uint256 _amountIn) private {
        address _tokenIn = ITokenManager(tokenManager).getToken(_collateralSymbol).addr;
        if (_collateralSymbol == bytes32("ETH")) { 
            IWETH(WETH).deposit{ value: _amountIn }();
            _tokenIn = WETH;
        };
        ISwapRouter(swapRouter).exactInputSingle({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: 3000,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
    }

    function swapAndDeposit(bytes32 _collateralSymbol, address _vault, uint256 _toSwap) private {
        address _token0 = IHypervisor(_vault).token0;
        address _token1 = IHypervisor(_vault).token1;
        swap(_collateralSymbol, _token0, _toSwap / 2);
        swap(_collateralSymbol, _token1, _toSwap / 2);
    }

    function depositYield(bytes32 _collateralSymbol, uint256 _euroPercentage) external payable {
        uint256 _balance = _collateralSymbol == bytes32("ETH") ?
            address(this).balance :
            IERC20(ITokenManager(tokenManager).getToken(_collateralSymbol).addr).balanceOf(address(this));
        uint256 _euroPortion = _euroPercentage * _balance / 1e5;
        swapAndDeposit(_collateralSymbol, eurosVault, _euroPortion);
        swapAndDeposit(_collateralSymbol, vaults[_collateralSymbol], _balance - _euroPortion);
    }
}

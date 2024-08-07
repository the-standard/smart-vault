// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/ISwapRouter.sol";
import "contracts/interfaces/IUniProxy.sol";
import "contracts/interfaces/IWETH.sol";

contract SmartVaultYieldManager is ISmartVaultYieldManager {
    address private immutable EUROs;
    address private immutable EURA;
    address private immutable WETH;
    address private immutable uniProxy;
    address private immutable eurosRouter;
    address private immutable euroVault;
    address private immutable uniswapRouter;
    uint256 private constant HUNDRED_PC = 1e5;
    mapping(address => VaultData) private vaultData;

    struct VaultData { address vaultAddr; uint24 poolFee; bytes pathToEURA; }

    constructor(address _EUROs, address _EURA, address _WETH, address _uniProxy, address _eurosRouter, address _euroVault, address _uniswapRouter) {
        EUROs = _EUROs;
        EURA = _EURA;
        WETH = _WETH;
        uniProxy = _uniProxy;
        eurosRouter = _eurosRouter;
        euroVault = _euroVault;
        uniswapRouter = _uniswapRouter;
    }

    function balance(address _token) private view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function swapToRatio(address _tokenA, address _hypervisor, address _swapRouter, uint24 _fee) private {
        address _tokenB = _tokenA == IHypervisor(_hypervisor).token0() ?
            IHypervisor(_hypervisor).token1() : IHypervisor(_hypervisor).token0();
        uint256 _tokenBBalance = balance(_tokenB);
        (uint256 amountStart, uint256 amountEnd) = IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, balance(_tokenA));
        uint256 _divisor = 2;
        bool _tokenBTooLarge;
        while(_tokenBBalance < amountStart || _tokenBBalance > amountEnd) {
            uint256 _midRatio = (amountStart + amountEnd) / 2;
            if (_tokenBBalance < _midRatio) {
                if (_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = false;
                }
                IERC20(_tokenA).approve(_swapRouter, balance(_tokenA));
                try ISwapRouter(_swapRouter).exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
                    tokenIn: _tokenA,
                    tokenOut: _tokenB,
                    fee: _fee,
                    recipient: address(this),
                    deadline: block.timestamp + 60,
                    amountOut: (_midRatio - _tokenBBalance) / _divisor,
                    amountInMaximum: balance(_tokenA),
                    sqrtPriceLimitX96: 0
                })) returns (uint256) {} catch {
                    _divisor++;
                }
            } else {
                if (!_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = true;
                }
                IERC20(_tokenB).approve(_swapRouter, (_tokenBBalance - _midRatio) / _divisor);
                try ISwapRouter(_swapRouter).exactInputSingle(ISwapRouter.ExactInputSingleParams({
                    tokenIn: _tokenB,
                    tokenOut: _tokenA,
                    fee: _fee,
                    recipient: address(this),
                    deadline: block.timestamp + 60,
                    amountIn: (_tokenBBalance - _midRatio) / _divisor,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })) returns (uint256) {} catch {
                    _divisor++;
                }
            }
            _tokenBBalance = balance(_tokenB);
            (amountStart, amountEnd) = IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, balance(_tokenA));
        }
    }

    function swapToEURA(address _collateralToken, uint256 _euroPercentage) private {
        uint256 _euroYieldPortion = balance(_collateralToken) * _euroPercentage / HUNDRED_PC;
        IERC20(_collateralToken).approve(eurosRouter, _euroYieldPortion);
        ISwapRouter(eurosRouter).exactInput(ISwapRouter.ExactInputParams({
            path: vaultData[_collateralToken].pathToEURA,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _euroYieldPortion,
            amountOutMinimum: 1
        }));
    }

    function deposit(address _vault) private {
        address _token0 = IHypervisor(_vault).token0();
        address _token1 = IHypervisor(_vault).token1();
        IERC20(_token0).approve(_vault, balance(_token0));
        IERC20(_token1).approve(_vault, balance(_token1));
        IUniProxy(uniProxy).deposit(balance(_token0), balance(_token1), msg.sender, _vault, [uint256(0),uint256(0),uint256(0),uint256(0)]);
    }

    function euroDeposit(address _collateralToken, uint256 _euroPercentage) private {
        swapToEURA(_collateralToken, _euroPercentage);
        swapToRatio(EURA, euroVault, eurosRouter, 500);
        deposit(euroVault);
    }

    function otherDeposit(address _collateralToken, VaultData memory _vaultData) private {
        swapToRatio(_collateralToken, _vaultData.vaultAddr, uniswapRouter, _vaultData.poolFee);
        deposit(_vaultData.vaultAddr);
    }

    function depositYield(address _collateralToken, uint256 _euroPercentage) external payable returns (address _vault0, address _vault1) {
        if (_collateralToken == address(0)) _collateralToken = WETH;
        IWETH(WETH).deposit{value: msg.value}();
        euroDeposit(_collateralToken, _euroPercentage);
        VaultData memory _vaultData = vaultData[_collateralToken];
        otherDeposit(_collateralToken, _vaultData);
        return (euroVault, _vaultData.vaultAddr);
    }

    function addVaultData(address _collateralToken, address _vaultAddr, uint24 _poolFee, bytes memory _EURASwapPath) external {
        vaultData[_collateralToken] = VaultData(_vaultAddr, _poolFee, _EURASwapPath);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/ISwapRouter.sol";
import "contracts/interfaces/IUniProxy.sol";
import "contracts/interfaces/IWETH.sol";

import "hardhat/console.sol";

contract SmartVaultYieldManager is ISmartVaultYieldManager, Ownable {
    using SafeERC20 for IERC20;

    address private immutable EUROs;
    address private immutable EURA;
    address private immutable WETH;
    address private immutable uniProxy;
    address private immutable eurosRouter;
    address private immutable euroVault;
    address private immutable uniswapRouter;
    uint256 private constant HUNDRED_PC = 1e5;
    mapping(address => VaultData) private vaultData;

    struct VaultData { address vault; uint24 poolFee; bytes pathToEURA; bytes pathFromEURA; }

    error InvalidRequest();

    constructor(address _EUROs, address _EURA, address _WETH, address _uniProxy, address _eurosRouter, address _euroVault, address _uniswapRouter) {
        EUROs = _EUROs;
        EURA = _EURA;
        WETH = _WETH;
        uniProxy = _uniProxy;
        eurosRouter = _eurosRouter;
        euroVault = _euroVault;
        uniswapRouter = _uniswapRouter;
    }

    function _thisBalanceOf(address _token) private view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _swapToRatio(address _tokenA, address _hypervisor, address _swapRouter, uint24 _fee) private {
        address _tokenB = _tokenA == IHypervisor(_hypervisor).token0() ?
            IHypervisor(_hypervisor).token1() : IHypervisor(_hypervisor).token0();
        uint256 _tokenBBalance = _thisBalanceOf(_tokenB);
        (uint256 amountStart, uint256 amountEnd) = IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, _thisBalanceOf(_tokenA));
        uint256 _divisor = 2;
        bool _tokenBTooLarge;
        while(_tokenBBalance < amountStart || _tokenBBalance > amountEnd) {
            uint256 _midRatio = (amountStart + amountEnd) / 2;
            if (_tokenBBalance < _midRatio) {
                if (_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = false;
                }
                IERC20(_tokenA).safeApprove(_swapRouter, _thisBalanceOf(_tokenA));
                try ISwapRouter(_swapRouter).exactOutputSingle(ISwapRouter.ExactOutputSingleParams({
                    tokenIn: _tokenA,
                    tokenOut: _tokenB,
                    fee: _fee,
                    recipient: address(this),
                    deadline: block.timestamp + 60,
                    amountOut: (_midRatio - _tokenBBalance) / _divisor,
                    amountInMaximum: _thisBalanceOf(_tokenA),
                    sqrtPriceLimitX96: 0
                })) returns (uint256) {} catch {
                    _divisor++;
                }
                IERC20(_tokenA).safeApprove(_swapRouter, 0);
            } else {
                if (!_tokenBTooLarge) {
                    _divisor++;
                    _tokenBTooLarge = true;
                }
                IERC20(_tokenB).safeApprove(_swapRouter, (_tokenBBalance - _midRatio) / _divisor);
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
                IERC20(_tokenB).safeApprove(_swapRouter, 0);
            }
            _tokenBBalance = _thisBalanceOf(_tokenB);
            (amountStart, amountEnd) = IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, _thisBalanceOf(_tokenA));
        }
    }

    function _swapToSingleAsset(address _vault, address _wantedToken, address _swapRouter, uint24 _fee) private {
        address _token0 = IHypervisor(_vault).token0();
        address _unwantedToken = IHypervisor(_vault).token0() == _wantedToken ?
            IHypervisor(_vault).token1() :
            _token0;
        uint256 _balance = _thisBalanceOf(_unwantedToken);
        IERC20(_unwantedToken).safeApprove(_swapRouter, _balance);
        ISwapRouter(_swapRouter).exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: _unwantedToken,
            tokenOut: _wantedToken,
            fee: _fee,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _balance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        }));
        IERC20(_unwantedToken).safeApprove(_swapRouter, 0);
    }

    function _swapToEURA(address _collateralToken, uint256 _euroPercentage, bytes memory _pathToEURA) private {
        uint256 _euroYieldPortion = _thisBalanceOf(_collateralToken) * _euroPercentage / HUNDRED_PC;
        IERC20(_collateralToken).safeApprove(uniswapRouter, _euroYieldPortion);
        ISwapRouter(uniswapRouter).exactInput(ISwapRouter.ExactInputParams({
            path: _pathToEURA,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _euroYieldPortion,
            amountOutMinimum: 1
        }));
        IERC20(_collateralToken).safeApprove(uniswapRouter, 0);
    }

    function _deposit(address _vault) private {
        address _token0 = IHypervisor(_vault).token0();
        address _token1 = IHypervisor(_vault).token1();
        IERC20(_token0).safeApprove(_vault, _thisBalanceOf(_token0));
        IERC20(_token1).safeApprove(_vault, _thisBalanceOf(_token1));
        IUniProxy(uniProxy).deposit(_thisBalanceOf(_token0), _thisBalanceOf(_token1), msg.sender, _vault, [uint256(0),uint256(0),uint256(0),uint256(0)]);
        IERC20(_token0).safeApprove(_vault, 0);
        IERC20(_token1).safeApprove(_vault, 0);
    }

    function _euroDeposit(address _collateralToken, uint256 _euroPercentage, bytes memory _pathToEURA) private {
        _swapToEURA(_collateralToken, _euroPercentage, _pathToEURA);
        _swapToRatio(EURA, euroVault, eurosRouter, 500);
        _deposit(euroVault);
    }

    function _otherDeposit(address _collateralToken, VaultData memory _vaultData) private {
        _swapToRatio(_collateralToken, _vaultData.vault, uniswapRouter, _vaultData.poolFee);
        _deposit(_vaultData.vault);
    }

    function deposit(address _collateralToken, uint256 _euroPercentage) external returns (address _vault0, address _vault1) {
        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), IERC20(_collateralToken).balanceOf(address(msg.sender)));
        VaultData memory _vaultData = vaultData[_collateralToken];
        if (_vaultData.vault == address(0)) revert InvalidRequest();
        _euroDeposit(_collateralToken, _euroPercentage, _vaultData.pathToEURA);
        _otherDeposit(_collateralToken, _vaultData);
        return (euroVault, _vaultData.vault);
        // TODO emit event
    }

    function _sellEUROs() private {
        uint256 _balance = _thisBalanceOf(EUROs);
        IERC20(EUROs).safeApprove(eurosRouter, _balance);
        ISwapRouter(eurosRouter).exactInputSingle(ISwapRouter.ExactInputSingleParams({
            tokenIn: EUROs,
            tokenOut: EURA,
            fee: 500,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _balance,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        }));
        IERC20(EUROs).safeApprove(eurosRouter, 0);
    }

    function _sellEURA(address _token) private {
        bytes memory _pathFromEURA = vaultData[_token].pathFromEURA;
        uint256 _balance = _thisBalanceOf(EURA);
        IERC20(EURA).safeApprove(uniswapRouter, _balance);
        ISwapRouter(uniswapRouter).exactInput(ISwapRouter.ExactInputParams({
            path: _pathFromEURA,
            recipient: msg.sender,
            deadline: block.timestamp + 60,
            amountIn: _balance,
            amountOutMinimum: 0
        }));
        IERC20(EUROs).safeApprove(uniswapRouter, 0);
    }

    function _withdrawEUROsDeposit(address _vault, address _token) private {
        IHypervisor(_vault).withdraw(_thisBalanceOf(_vault), address(this), address(this), [uint256(0),uint256(0),uint256(0),uint256(0)]);
        _sellEUROs();
        _sellEURA(_token);
    }

    function _withdrawOtherDeposit(address _vault, address _token) private {
        VaultData memory _vaultData = vaultData[_token];
        if (_vaultData.vault != _vault) revert InvalidRequest();
        IHypervisor(_vault).withdraw(_thisBalanceOf(_vault), address(this), address(this), [uint256(0),uint256(0),uint256(0),uint256(0)]);
        _swapToSingleAsset(_vault, _token, uniswapRouter, _vaultData.poolFee);
        IERC20(_token).safeTransfer(msg.sender, _thisBalanceOf(_token));
    }

    function withdraw(address _vault, address _token) external {
        IERC20(_vault).safeTransferFrom(msg.sender, address(this), IERC20(_vault).balanceOf(msg.sender));
        _vault == euroVault ? 
            _withdrawEUROsDeposit(_vault, _token) :
            _withdrawOtherDeposit(_vault, _token);
        // TODO emit event
    }

    function addVaultData(address _collateralToken, address _vault, uint24 _poolFee, bytes memory _pathToEURA, bytes memory _pathFromEURA) external {
        vaultData[_collateralToken] = VaultData(_vault, _poolFee, _pathToEURA, _pathFromEURA);
    }

    function removeVaultData(address _collateralToken) external onlyOwner {
        delete vaultData[_collateralToken];
    }
}

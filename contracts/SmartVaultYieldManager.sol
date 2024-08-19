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

    struct VaultData { address vaultAddr; uint24 poolFee; bytes pathToEURA; bytes pathFromEURA; }

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
                IERC20(_tokenA).safeApprove(_swapRouter, balance(_tokenA));
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
            _tokenBBalance = balance(_tokenB);
            (amountStart, amountEnd) = IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, balance(_tokenA));
        }
    }

    function swapToEURA(address _collateralToken, uint256 _euroPercentage, bytes memory _pathToEURA) private {
        uint256 _euroYieldPortion = balance(_collateralToken) * _euroPercentage / HUNDRED_PC;
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

    function deposit(address _vault) private {
        address _token0 = IHypervisor(_vault).token0();
        address _token1 = IHypervisor(_vault).token1();
        IERC20(_token0).safeApprove(_vault, balance(_token0));
        IERC20(_token1).safeApprove(_vault, balance(_token1));
        IUniProxy(uniProxy).deposit(balance(_token0), balance(_token1), msg.sender, _vault, [uint256(0),uint256(0),uint256(0),uint256(0)]);
        IERC20(_token0).safeApprove(_vault, 0);
        IERC20(_token1).safeApprove(_vault, 0);
    }

    function euroDeposit(address _collateralToken, uint256 _euroPercentage, bytes memory _pathToEURA) private {
        swapToEURA(_collateralToken, _euroPercentage, _pathToEURA);
        swapToRatio(EURA, euroVault, eurosRouter, 500);
        deposit(euroVault);
    }

    function otherDeposit(address _collateralToken, VaultData memory _vaultData) private {
        swapToRatio(_collateralToken, _vaultData.vaultAddr, uniswapRouter, _vaultData.poolFee);
        deposit(_vaultData.vaultAddr);
    }

    function deposit(address _collateralToken, uint256 _euroPercentage) external returns (address _vault0, address _vault1) {
        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), IERC20(_collateralToken).balanceOf(address(msg.sender)));
        VaultData memory _vaultData = vaultData[_collateralToken];
        require(_vaultData.vaultAddr != address(0), "err-invalid-request");
        euroDeposit(_collateralToken, _euroPercentage, _vaultData.pathToEURA);
        otherDeposit(_collateralToken, _vaultData);
        return (euroVault, _vaultData.vaultAddr);
    }

    function sellEUROs() private {
        uint256 _balance = balance(EUROs);
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

    function sellEURA(address _token) private {
        bytes memory _pathFromEURA = vaultData[_token].pathFromEURA;
        uint256 _balance = balance(EURA);
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

    function withdrawEUROsDeposit(address _token) private {
        IHypervisor(euroVault).withdraw(balance(euroVault), address(this), address(this), [uint256(0),uint256(0),uint256(0),uint256(0)]);
        sellEUROs();
        sellEURA(_token);
    }

    function withdraw(address _vault, address _token) external {
        IERC20(_vault).safeTransferFrom(msg.sender, address(this), IERC20(_vault).balanceOf(msg.sender));
        if (_vault == euroVault) {
            withdrawEUROsDeposit(_token);
        }
    }

    function addVaultData(address _collateralToken, address _vaultAddr, uint24 _poolFee, bytes memory _pathToEURA, bytes memory _pathFromEURA) external {
        vaultData[_collateralToken] = VaultData(_vaultAddr, _poolFee, _pathToEURA, _pathFromEURA);
    }

    function removeVaultData(address _collateralToken) external onlyOwner {
        delete vaultData[_collateralToken];
    }
}

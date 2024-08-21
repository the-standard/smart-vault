// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
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
    address private immutable euroHypervisor;
    address private immutable uniswapRouter;
    uint256 private constant HUNDRED_PC = 1e5;
    // min 10% to euros pool
    uint256 private constant MIN_EURO_PERCENTAGE = 1e4;
    address private smartVaultManager;
    uint256 public feeRate;
    mapping(address => HypervisorData) private hypervisorData;

    struct HypervisorData { address hypervisor; uint24 poolFee; bytes pathToEURA; bytes pathFromEURA; }

    event Deposit(address indexed smartVault, address indexed token, uint256 amount, uint256 euroPercentage);
    event Withdraw(address indexed smartVault, address indexed token, address hypervisor, uint256 amount);
    error InvalidRequest();

    constructor(address _EUROs, address _EURA, address _WETH, address _uniProxy, address _eurosRouter, address _euroHypervisor, address _uniswapRouter) {
        EUROs = _EUROs;
        EURA = _EURA;
        WETH = _WETH;
        uniProxy = _uniProxy;
        eurosRouter = _eurosRouter;
        euroHypervisor = _euroHypervisor;
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

    function _swapToSingleAsset(address _hypervisor, address _wantedToken, address _swapRouter, uint24 _fee) private {
        address _token0 = IHypervisor(_hypervisor).token0();
        address _unwantedToken = IHypervisor(_hypervisor).token0() == _wantedToken ?
            IHypervisor(_hypervisor).token1() :
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

    function _deposit(address _hypervisor) private {
        address _token0 = IHypervisor(_hypervisor).token0();
        address _token1 = IHypervisor(_hypervisor).token1();
        IERC20(_token0).safeApprove(_hypervisor, _thisBalanceOf(_token0));
        IERC20(_token1).safeApprove(_hypervisor, _thisBalanceOf(_token1));
        IUniProxy(uniProxy).deposit(_thisBalanceOf(_token0), _thisBalanceOf(_token1), msg.sender, _hypervisor, [uint256(0),uint256(0),uint256(0),uint256(0)]);
        IERC20(_token0).safeApprove(_hypervisor, 0);
        IERC20(_token1).safeApprove(_hypervisor, 0);
    }

    function _euroDeposit(address _collateralToken, uint256 _euroPercentage, bytes memory _pathToEURA) private {
        _swapToEURA(_collateralToken, _euroPercentage, _pathToEURA);
        _swapToRatio(EURA, euroHypervisor, eurosRouter, 500);
        _deposit(euroHypervisor);
    }

    function _otherDeposit(address _collateralToken, HypervisorData memory _hypervisorData) private {
        _swapToRatio(_collateralToken, _hypervisorData.hypervisor, uniswapRouter, _hypervisorData.poolFee);
        _deposit(_hypervisorData.hypervisor);
    }

    function deposit(address _collateralToken, uint256 _euroPercentage) external returns (address _hypervisor0, address _hypervisor1) {
        if (_euroPercentage < MIN_EURO_PERCENTAGE) revert InvalidRequest();
        uint256 _balance = IERC20(_collateralToken).balanceOf(address(msg.sender));
        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _balance);
        HypervisorData memory _hypervisorData = hypervisorData[_collateralToken];
        if (_hypervisorData.hypervisor == address(0)) revert InvalidRequest();
        _euroDeposit(_collateralToken, _euroPercentage, _hypervisorData.pathToEURA);
        _otherDeposit(_collateralToken, _hypervisorData);
        emit Deposit(msg.sender, _collateralToken, _balance, _euroPercentage);
        return (euroHypervisor, _hypervisorData.hypervisor);
    }

    function _sellEURA(address _token) private {
        bytes memory _pathFromEURA = hypervisorData[_token].pathFromEURA;
        uint256 _balance = _thisBalanceOf(EURA);
        IERC20(EURA).safeApprove(uniswapRouter, _balance);
        ISwapRouter(uniswapRouter).exactInput(ISwapRouter.ExactInputParams({
            path: _pathFromEURA,
            recipient: address(this),
            deadline: block.timestamp + 60,
            amountIn: _balance,
            amountOutMinimum: 0
        }));
        IERC20(EUROs).safeApprove(uniswapRouter, 0);
    }

    function _withdrawEUROsDeposit(address _hypervisor, address _token) private {
        IHypervisor(_hypervisor).withdraw(_thisBalanceOf(_hypervisor), address(this), address(this), [uint256(0),uint256(0),uint256(0),uint256(0)]);
        _swapToSingleAsset(euroHypervisor, EURA, eurosRouter, 500);
        _sellEURA(_token);
    }

    function _withdrawOtherDeposit(address _hypervisor, address _token) private {
        HypervisorData memory _hypervisorData = hypervisorData[_token];
        if (_hypervisorData.hypervisor != _hypervisor) revert InvalidRequest();
        IHypervisor(_hypervisor).withdraw(_thisBalanceOf(_hypervisor), address(this), address(this), [uint256(0),uint256(0),uint256(0),uint256(0)]);
        _swapToSingleAsset(_hypervisor, _token, uniswapRouter, _hypervisorData.poolFee);
    }

    function withdraw(address _hypervisor, address _token) external {
        IERC20(_hypervisor).safeTransferFrom(msg.sender, address(this), IERC20(_hypervisor).balanceOf(msg.sender));
        _hypervisor == euroHypervisor ? 
            _withdrawEUROsDeposit(_hypervisor, _token) :
            _withdrawOtherDeposit(_hypervisor, _token);
        uint256 _withdrawn = _thisBalanceOf(_token);
        uint256 _fee = _withdrawn * feeRate / HUNDRED_PC;
        _withdrawn = _withdrawn - _fee;
        IERC20(_token).safeTransfer(ISmartVaultManager(smartVaultManager).protocol(), _fee);
        IERC20(_token).safeTransfer(msg.sender, _withdrawn);
        emit Withdraw(msg.sender, _token, _hypervisor, _withdrawn);
    }

    function addHypervisorData(address _collateralToken, address _hypervisor, uint24 _poolFee, bytes memory _pathToEURA, bytes memory _pathFromEURA) external {
        hypervisorData[_collateralToken] = HypervisorData(_hypervisor, _poolFee, _pathToEURA, _pathFromEURA);
    }

    function removeHypervisorData(address _collateralToken) external onlyOwner {
        delete hypervisorData[_collateralToken];
    }
    
    function setFeeData(uint256 _feeRate, address _smartVaultManager) external {
        feeRate = _feeRate;
        smartVaultManager = _smartVaultManager;
    }
}

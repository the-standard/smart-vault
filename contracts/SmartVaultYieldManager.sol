// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "contracts/uniswap/FullMath.sol";
import "contracts/uniswap/PoolAddress.sol";
import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/IPeripheryImmutableState.sol";
import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/ISmartVaultManager.sol";
import "contracts/interfaces/ISwapRouter.sol";
import "contracts/interfaces/IUniProxy.sol";
import "contracts/interfaces/IUniswapV3Pool.sol";
import "contracts/interfaces/IWETH.sol";
import "contracts/interfaces/IPeripheryImmutableState.sol";
import "contracts/interfaces/IUniswapV3Pool.sol";

import {PoolAddress} from "contracts/uniswap/PoolAddress.sol";
import {FullMath} from "contracts/uniswap/FullMath.sol";
import {IPeripheryImmutableState} from "contracts/interfaces/IPeripheryImmutableState.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";

contract SmartVaultYieldManager is ISmartVaultYieldManager, Ownable {
    using SafeERC20 for IERC20;

    address private immutable USDs;
    address private immutable USDC;
    address private immutable WETH;
    address private immutable uniProxy;
    address private immutable ramsesRouter;
    address private immutable usdsHypervisor;
    address private immutable uniswapRouter;
    uint256 private constant HUNDRED_PC = 1e5;
    // min 10% to usds pool
    uint256 private constant MIN_USDS_PERCENTAGE = 1e4;
    address private smartVaultManager;
    uint256 public feeRate;
    mapping(address => HypervisorData) private hypervisorData;

    struct HypervisorData {
        address hypervisor;
        uint24 poolFee;
        bytes pathToUSDC;
        bytes pathFromUSDC;
    }

    event Deposit(address indexed smartVault, address indexed token, uint256 amount, uint256 usdPercentage);
    event Withdraw(address indexed smartVault, address indexed token, address hypervisor, uint256 amount);

    error RatioError();
    error StablePoolPercentageError();
    error HypervisorDataError();
    error IncompatibleHypervisor();

    constructor(
        address _USDs,
        address _USDC,
        address _WETH,
        address _uniProxy,
        address _ramsesRouter,
        address _usdsHypervisor,
        address _uniswapRouter
    ) Ownable(msg.sender) {
        USDs = _USDs;
        USDC = _USDC;
        WETH = _WETH;
        uniProxy = _uniProxy;
        ramsesRouter = _ramsesRouter;
        usdsHypervisor = _usdsHypervisor;
        uniswapRouter = _uniswapRouter;
    }

    function _thisBalanceOf(address _token) private view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function _withinRatio(uint256 _tokenBBalance, uint256 _requiredStart, uint256 _requiredEnd)
        private
        pure
        returns (bool)
    {
        return _tokenBBalance >= _requiredStart && _tokenBBalance <= _requiredEnd;
    }

    function _swapToRatio(address _tokenA, address _hypervisor, address _swapRouter, uint24 _fee) private {
        address _token0 = IHypervisor(_hypervisor).token0();
        address _token1 = IHypervisor(_hypervisor).token1();

        address _tokenB = _tokenA == _token0 ? _token1 : _token0;

        uint160 _sqrtPriceX96;
        {
            PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(_token0, _token1, _fee);
            address factory = IPeripheryImmutableState(_swapRouter).factory();
            (_sqrtPriceX96,,,,,,) = _swapRouter == uniswapRouter
                ? IUniswapV3Pool(PoolAddress.computeAddressUniswap(factory, poolKey)).slot0()
                : IUniswapV3Pool(PoolAddress.computeAddressRamses(factory, poolKey)).slot0();
        }

        uint256 _midRatio;
        {
            (uint256 _amountStart, uint256 _amountEnd) =
                IUniProxy(uniProxy).getDepositAmount(_hypervisor, _tokenA, _thisBalanceOf(_tokenA));
            if (_withinRatio(_thisBalanceOf(_tokenB), _amountStart, _amountEnd)) return;

            _midRatio = (_amountStart + _amountEnd) / 2;
        }

        bool _tokenAIs0 = _tokenA == _token0;
        uint256 _tokenBBalance = _thisBalanceOf(_tokenB);
        uint256 _tokenABalance = _thisBalanceOf(_tokenA);

        uint256 _amountIn;
        uint256 _amountOut;

        // Push _fee back on to the stack
        uint24 _fee = _fee;

        {
            uint256 aDec = ERC20(_tokenA).decimals();
            uint256 bDec = ERC20(_tokenB).decimals();

            uint256 price36;
            {
                uint256 priceX192 = uint256(_sqrtPriceX96) * _sqrtPriceX96;
                price36 = _tokenAIs0
                    ? FullMath.mulDiv((10 ** aDec) * (10 ** (36 - bDec)), 1 << 192, priceX192)
                    : FullMath.mulDiv((10 ** bDec) * (10 ** (36 - aDec)), priceX192, 1 << 192);
            }

            uint256 _ratio =
                FullMath.mulDiv(_tokenABalance * (10 ** (36 - aDec)), 1e36, _midRatio * (10 ** (36 - bDec)));
            uint256 _rb = FullMath.mulDiv(_tokenBBalance * (10 ** (36 - bDec)), _ratio, 1e36);

            if (_tokenABalance * (10 ** (36 - aDec)) > _rb) {
                // a -> b

                uint256 _denominator =
                    1e36 + FullMath.mulDiv(_ratio - FullMath.mulDiv(_ratio, _fee, 1e6), 1e36, price36);
                // a - rb / (1 + (1-f) * ratio / price)
                _amountIn =
                    FullMath.mulDiv(_tokenABalance * (10 ** (36 - aDec)) - _rb, 1e36, _denominator) / 10 ** (36 - aDec);
            } else {
                // b -> a

                uint256 _denominator =
                    1e36 + FullMath.mulDiv(_ratio, 1e36, price36 + FullMath.mulDiv(price36, _fee, 1e6));
                // rb - a / (1 + ratio / ((1+f) * price))
                _amountOut =
                    FullMath.mulDiv(_rb - _tokenABalance * (10 ** (36 - aDec)), 1e36, _denominator) / 10 ** (36 - aDec);
            }
        }

        if (_tokenBBalance < _midRatio) {
            // we want more tokenB

            address _tokenIn = _tokenAIs0 ? _token0 : _token1;
            address _tokenOut = _tokenAIs0 ? _token1 : _token0;

            IERC20(_tokenIn).safeIncreaseAllowance(_swapRouter, _tokenABalance);
            ISwapRouter(_swapRouter).exactInputSingle(
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    fee: _fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: _amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
            IERC20(_tokenIn).forceApprove(_swapRouter, 0);
        } else {
            // we want more tokenA

            address _tokenIn = _tokenAIs0 ? _token1 : _token0;
            address _tokenOut = _tokenAIs0 ? _token0 : _token1;

            IERC20(_tokenIn).safeIncreaseAllowance(_swapRouter, _tokenBBalance);
            ISwapRouter(_swapRouter).exactOutputSingle(
                ISwapRouter.ExactOutputSingleParams({
                    tokenIn: _tokenIn,
                    tokenOut: _tokenOut,
                    fee: _fee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountOut: _amountOut,
                    amountInMaximum: _tokenBBalance,
                    sqrtPriceLimitX96: 0
                })
            );
            IERC20(_tokenIn).forceApprove(_swapRouter, 0);
        }
    }

    function _swapToSingleAsset(address _hypervisor, address _wantedToken, address _swapRouter, uint24 _fee) private {
        address _token0 = IHypervisor(_hypervisor).token0();
        address _unwantedToken = _token0 == _wantedToken ? IHypervisor(_hypervisor).token1() : _token0;
        uint256 _balance = _thisBalanceOf(_unwantedToken);
        IERC20(_unwantedToken).safeIncreaseAllowance(_swapRouter, _balance);
        ISwapRouter(_swapRouter).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _unwantedToken,
                tokenOut: _wantedToken,
                fee: _fee,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: _balance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
        IERC20(_unwantedToken).forceApprove(_swapRouter, 0);
        // transfer any dust amounts of unwanted token to smart vault
        IERC20(_unwantedToken).safeTransfer(msg.sender, _thisBalanceOf(_unwantedToken));
    }

    function _swapToUSDC(address _collateralToken, uint256 _usdPercentage, bytes memory _pathToUSDC) private {
        uint256 _usdYieldPortion = _thisBalanceOf(_collateralToken) * _usdPercentage / HUNDRED_PC;
        IERC20(_collateralToken).safeIncreaseAllowance(uniswapRouter, _usdYieldPortion);
        ISwapRouter(uniswapRouter).exactInput(
            ISwapRouter.ExactInputParams({
                path: _pathToUSDC,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: _usdYieldPortion,
                amountOutMinimum: 1
            })
        );
        IERC20(_collateralToken).forceApprove(uniswapRouter, 0);
    }

    function _deposit(address _hypervisor) private {
        address _token0 = IHypervisor(_hypervisor).token0();
        address _token1 = IHypervisor(_hypervisor).token1();
        IERC20(_token0).safeIncreaseAllowance(_hypervisor, _thisBalanceOf(_token0));
        IERC20(_token1).safeIncreaseAllowance(_hypervisor, _thisBalanceOf(_token1));
        IUniProxy(uniProxy).deposit(
            _thisBalanceOf(_token0),
            _thisBalanceOf(_token1),
            msg.sender,
            _hypervisor,
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        IERC20(_token0).forceApprove(_hypervisor, 0);
        IERC20(_token1).forceApprove(_hypervisor, 0);
    }

    function _usdDeposit(address _collateralToken, uint256 _usdPercentage, bytes memory _pathToUSDC) private {
        _swapToUSDC(_collateralToken, _usdPercentage, _pathToUSDC);
        _swapToRatio(USDC, usdsHypervisor, ramsesRouter, 500);
        _deposit(usdsHypervisor);
    }

    function _otherDeposit(address _collateralToken, HypervisorData memory _hypervisorData) private {
        _swapToRatio(_collateralToken, _hypervisorData.hypervisor, uniswapRouter, _hypervisorData.poolFee);
        _deposit(_hypervisorData.hypervisor);
    }

    function deposit(address _collateralToken, uint256 _usdPercentage)
        external
        returns (address _hypervisor0, address _hypervisor1)
    {
        if (_usdPercentage < MIN_USDS_PERCENTAGE) revert StablePoolPercentageError();
        uint256 _balance = IERC20(_collateralToken).balanceOf(msg.sender);
        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _balance);
        HypervisorData memory _hypervisorData = hypervisorData[_collateralToken];
        if (_hypervisorData.hypervisor == address(0)) revert HypervisorDataError();
        _usdDeposit(_collateralToken, _usdPercentage, _hypervisorData.pathToUSDC);
        _hypervisor0 = usdsHypervisor;
        if (_usdPercentage < HUNDRED_PC) {
            _otherDeposit(_collateralToken, _hypervisorData);
            _hypervisor1 = _hypervisorData.hypervisor;
        }
        emit Deposit(msg.sender, _collateralToken, _balance, _usdPercentage);
    }

    function _sellUSDC(address _token) private {
        bytes memory _pathFromUSDC = hypervisorData[_token].pathFromUSDC;
        uint256 _balance = _thisBalanceOf(USDC);
        IERC20(USDC).safeIncreaseAllowance(uniswapRouter, _balance);
        ISwapRouter(uniswapRouter).exactInput(
            ISwapRouter.ExactInputParams({
                path: _pathFromUSDC,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: _balance,
                amountOutMinimum: 0
            })
        );
        IERC20(USDC).forceApprove(uniswapRouter, 0);
    }

    function _withdrawUSDsDeposit(address _token) private {
        IHypervisor(usdsHypervisor).withdraw(
            _thisBalanceOf(usdsHypervisor),
            address(this),
            address(this),
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        _swapToSingleAsset(usdsHypervisor, USDC, ramsesRouter, 500);
        _sellUSDC(_token);
    }

    function _withdrawOtherDeposit(address _hypervisor, address _token) private {
        HypervisorData memory _hypervisorData = hypervisorData[_token];
        if (_hypervisorData.hypervisor != _hypervisor) revert IncompatibleHypervisor();
        IHypervisor(_hypervisor).withdraw(
            _thisBalanceOf(_hypervisor), address(this), address(this), [uint256(0), uint256(0), uint256(0), uint256(0)]
        );
        _swapToSingleAsset(_hypervisor, _token, uniswapRouter, _hypervisorData.poolFee);
    }

    function withdraw(address _hypervisor, address _token) external {
        IERC20(_hypervisor).safeTransferFrom(msg.sender, address(this), IERC20(_hypervisor).balanceOf(msg.sender));
        _hypervisor == usdsHypervisor ? _withdrawUSDsDeposit(_token) : _withdrawOtherDeposit(_hypervisor, _token);
        uint256 _withdrawn = _thisBalanceOf(_token);
        uint256 _fee = _withdrawn * feeRate / HUNDRED_PC;
        _withdrawn = _withdrawn - _fee;
        IERC20(_token).safeTransfer(ISmartVaultManager(smartVaultManager).protocol(), _fee);
        IERC20(_token).safeTransfer(msg.sender, _withdrawn);
        emit Withdraw(msg.sender, _token, _hypervisor, _withdrawn);
    }

    function addHypervisorData(
        address _collateralToken,
        address _hypervisor,
        uint24 _poolFee,
        bytes memory _pathToUSDC,
        bytes memory _pathFromUSDC
    ) external onlyOwner {
        hypervisorData[_collateralToken] = HypervisorData(_hypervisor, _poolFee, _pathToUSDC, _pathFromUSDC);
    }

    function removeHypervisorData(address _collateralToken) external onlyOwner {
        delete hypervisorData[_collateralToken];
    }

    function setFeeData(uint256 _feeRate, address _smartVaultManager) external onlyOwner {
        feeRate = _feeRate;
        smartVaultManager = _smartVaultManager;
    }
}

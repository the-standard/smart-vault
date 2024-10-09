// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "contracts/interfaces/IHypervisor.sol";
import "contracts/interfaces/IPriceCalculator.sol";
import "contracts/interfaces/ISmartVault.sol";
import "contracts/interfaces/ISmartVaultManagerV3.sol";
import "contracts/interfaces/ISmartVaultYieldManager.sol";
import "contracts/interfaces/ISwapRouter.sol";
import "contracts/interfaces/ITokenManager.sol";
import "contracts/interfaces/IUSDs.sol";
import "contracts/interfaces/IWETH.sol";

contract SmartVaultV4 is ISmartVault {
    using SafeERC20 for IERC20;

    uint8 private constant version = 4;
    bytes32 private constant vaultType = bytes32("USDs");
    bytes32 private immutable NATIVE;
    address public immutable manager;
    IUSDs public immutable USDs;
    IPriceCalculator public immutable calculator;
    address[] private hypervisors;

    address public owner;
    uint256 private minted;
    bool private liquidated;

    struct YieldPair {
        address hypervisor;
        address token0;
        uint256 amount0;
        address token1;
        uint256 amount1;
    }

    event CollateralRemoved(bytes32 symbol, uint256 amount, address to);
    event AssetRemoved(address token, uint256 amount, address to);
    event USDsMinted(address to, uint256 amount, uint256 fee);
    event USDsBurned(uint256 amount, uint256 fee);
    event FailedTransfer(address token, uint256 amount);

    error InvalidUser();
    error VaultLiquidated();
    error Overrepay();
    error TransferError();
    error NotUndercollateralised();
    error Undercollateralised();
    error InvalidToken();
    error DeadlineExpired();

    constructor(bytes32 _native, address _manager, address _owner, address _usds, address _priceCalculator) {
        NATIVE = _native;
        owner = _owner;
        manager = _manager;
        USDs = IUSDs(_usds);
        calculator = IPriceCalculator(_priceCalculator);
    }

    modifier onlyVaultManager() {
        if (msg.sender != manager) revert InvalidUser();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert InvalidUser();
        _;
    }

    modifier ifMinted(uint256 _amount) {
        if (minted < _amount) revert Overrepay();
        _;
    }

    modifier ifNotLiquidated() {
        if (liquidated) revert VaultLiquidated();
        _;
    }

    modifier remainCollateralised() {
        _;
        if (undercollateralised()) revert Undercollateralised();
    }

    modifier withinTimestamp(uint256 _deadline) {
        _;
        if (block.timestamp > _deadline) revert DeadlineExpired();
    }

    function getTokenManager() private view returns (ITokenManager) {
        return ITokenManager(ISmartVaultManagerV3(manager).tokenManager());
    }

    function yieldVaultCollateral(ITokenManager.Token[] memory _acceptedTokens) private view returns (uint256 _usd) {
        for (uint256 i = 0; i < hypervisors.length; i++) {
            IHypervisor _Hypervisor = IHypervisor(hypervisors[i]);
            uint256 _balance = _Hypervisor.balanceOf(address(this));
            if (_balance > 0) {
                uint256 _totalSupply = _Hypervisor.totalSupply();
                (uint256 _underlyingTotal0, uint256 _underlyingTotal1) = _Hypervisor.getTotalAmounts();
                address _token0 = _Hypervisor.token0();
                address _token1 = _Hypervisor.token1();
                uint256 _underlying0 = _balance * _underlyingTotal0 / _totalSupply;
                uint256 _underlying1 = _balance * _underlyingTotal1 / _totalSupply;
                if (_token0 == address(USDs)) {
                    // if token 0 is usds, we can use token 1 (usdc) as collateral
                    _usd += calculator.USDCToUSD(_underlying1, ERC20(_token1).decimals());
                } else if (_token1 == address(USDs)) {
                    // if token 1 is usds, we can use token 0 (usdc) as collateral
                    _usd += calculator.USDCToUSD(_underlying0, ERC20(_token0).decimals());
                } else {
                    for (uint256 j = 0; j < _acceptedTokens.length; j++) {
                        ITokenManager.Token memory _token = _acceptedTokens[j];
                        if (_token.addr == _token0) _usd += calculator.tokenToUSD(_token, _underlying0);
                        if (_token.addr == _token1) _usd += calculator.tokenToUSD(_token, _underlying1);
                    }
                }
            }
        }
    }

    function usdCollateral() private view returns (uint256 _usd) {
        ITokenManager tokenManager = ITokenManager(ISmartVaultManagerV3(manager).tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory _token = acceptedTokens[i];
            _usd += calculator.tokenToUSD(_token, getAssetBalance(_token.addr));
        }

        _usd += yieldVaultCollateral(acceptedTokens);
    }

    function maxMintable(uint256 _collateral) private view returns (uint256) {
        return _collateral * ISmartVaultManagerV3(manager).HUNDRED_PC() / ISmartVaultManagerV3(manager).collateralRate();
    }

    function getAssetBalance(address _tokenAddress) private view returns (uint256 amount) {
        return _tokenAddress == address(0) ? address(this).balance : IERC20(_tokenAddress).balanceOf(address(this));
    }

    function getAssets() private view returns (Asset[] memory) {
        ITokenManager tokenManager = ITokenManager(ISmartVaultManagerV3(manager).tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        Asset[] memory assets = new Asset[](acceptedTokens.length);
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory token = acceptedTokens[i];
            uint256 assetBalance = getAssetBalance(token.addr);
            assets[i] = Asset(token, assetBalance, calculator.tokenToUSD(token, assetBalance));
        }
        return assets;
    }

    function status() external view returns (Status memory) {
        uint256 _collateral = usdCollateral();
        return Status(
            address(this), minted, maxMintable(_collateral), _collateral, getAssets(), liquidated, version, vaultType
        );
    }

    function _undercollateralised(uint256 _usdCollateral) private view returns (bool) {
        return minted > maxMintable(_usdCollateral);
    }

    function undercollateralised() public view returns (bool) {
        return _undercollateralised(usdCollateral());
    }

    function liquidate(address _liquidator) external onlyVaultManager {
        if (!undercollateralised()) revert NotUndercollateralised();
        liquidated = true;
        minted = 0;
        // remove all erc20 collateral
        ITokenManager.Token[] memory tokens =
            ITokenManager(ISmartVaultManagerV3(manager).tokenManager()).getAcceptedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].symbol != NATIVE) {
                IERC20 _token = IERC20(tokens[i].addr);
                if (_token.balanceOf(address(this)) != 0) {
                    try _token.transfer(_liquidator, _token.balanceOf(address(this))) {}
                    catch {
                        emit FailedTransfer(address(_token), _token.balanceOf(address(this)));
                    }
                }
            }
        }
        // remove all hypervisor tokens
        for (uint256 i = 0; i < hypervisors.length; i++) {
            IERC20 _hypervisor = IERC20(hypervisors[i]);
            if (_hypervisor.balanceOf(address(this)) != 0) {
                _hypervisor.safeTransfer(_liquidator, _hypervisor.balanceOf(address(this)));
            }
        }
        // remove eth
        if (address(this).balance != 0) {
            (bool sent,) = payable(_liquidator).call{value: address(this).balance}("");
            if (!sent) revert TransferError();
        }
    }

    receive() external payable {}

    function removeCollateralNative(uint256 _amount, address payable _to) public onlyOwner {
        if (minted > 0) {
            uint256 _usdValueToRemove = calculator.tokenToUSD(getToken(NATIVE), _amount);
            if (minted > maxMintable(usdCollateral() - _usdValueToRemove)) revert Undercollateralised();
        }
        (bool sent,) = _to.call{value: _amount}("");
        if (!sent) revert TransferError();
        emit CollateralRemoved(NATIVE, _amount, _to);
    }

    function removeCollateral(bytes32 _symbol, uint256 _amount, address _to) external onlyOwner remainCollateralised {
        ITokenManager.Token memory token = getTokenManager().getToken(_symbol);
        IERC20(token.addr).safeTransfer(_to, _amount);
        emit CollateralRemoved(_symbol, _amount, _to);
    }

    function removeAsset(address _tokenAddr, uint256 _amount, address _to) external onlyOwner remainCollateralised {
        if (_tokenAddr == address(0)) return removeCollateralNative(_amount, payable(_to));
        IERC20(_tokenAddr).safeTransfer(_to, _amount);
        emit AssetRemoved(_tokenAddr, _amount, _to);
    }

    function mint(address _to, uint256 _amount) external onlyOwner ifNotLiquidated remainCollateralised {
        uint256 fee = _amount * ISmartVaultManagerV3(manager).mintFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        minted = minted + _amount + fee;
        USDs.mint(_to, _amount);
        USDs.mint(ISmartVaultManagerV3(manager).protocol(), fee);
        emit USDsMinted(_to, _amount, fee);
    }

    function burn(uint256 _amount) external ifMinted(_amount) {
        uint256 fee = _amount * ISmartVaultManagerV3(manager).burnFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        minted = minted - _amount;
        USDs.burn(msg.sender, _amount + fee);
        if (fee > 0) USDs.mint(ISmartVaultManagerV3(manager).protocol(), fee);
        emit USDsBurned(_amount, fee);
    }

    function getToken(bytes32 _symbol) private view returns (ITokenManager.Token memory _token) {
        ITokenManager.Token[] memory tokens =
            ITokenManager(ISmartVaultManagerV3(manager).tokenManager()).getAcceptedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].symbol == _symbol) _token = tokens[i];
        }
        if (_token.symbol == bytes32(0)) revert InvalidToken();
    }

    function getTokenisedAddr(bytes32 _symbol) private view returns (address) {
        ITokenManager.Token memory _token = getToken(_symbol);
        return _token.addr == address(0) ? ISmartVaultManagerV3(manager).weth() : _token.addr;
    }

    function executeSwapAndFee(ISwapRouter.ExactInputSingleParams memory _params, uint256 _swapFee)
        private
        returns (uint256 _amountOut)
    {
        IERC20(_params.tokenIn).safeTransfer(ISmartVaultManagerV3(manager).protocol(), _swapFee);
        IERC20(_params.tokenIn).safeIncreaseAllowance(ISmartVaultManagerV3(manager).swapRouter(), _params.amountIn);
        _amountOut = ISwapRouter(ISmartVaultManagerV3(manager).swapRouter()).exactInputSingle(_params);
        IERC20(_params.tokenIn).forceApprove(ISmartVaultManagerV3(manager).swapRouter(), 0);
    }

    function swap(bytes32 _inToken, bytes32 _outToken, uint256 _amount, uint256 _minOut, uint24 _fee, uint256 _deadline)
        external
        onlyOwner
        remainCollateralised
    {
        uint256 swapFee =
            _amount * ISmartVaultManagerV3(manager).swapFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        address inToken = getTokenisedAddr(_inToken);
        if (_inToken == NATIVE) IWETH(ISmartVaultManagerV3(manager).weth()).deposit{value: _amount}();
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: inToken,
            tokenOut: getTokenisedAddr(_outToken),
            fee: _fee,
            recipient: address(this),
            deadline: _deadline,
            amountIn: _amount - swapFee,
            amountOutMinimum: _minOut,
            sqrtPriceLimitX96: 0
        });
        uint256 _amountOut = executeSwapAndFee(params, swapFee);
        if (_outToken == NATIVE) {
            IWETH(ISmartVaultManagerV3(manager).weth()).withdraw(_amountOut);
        }
    }

    function autoRedemption(
        address _swapRouterAddress,
        address _collateralAddr,
        bytes memory _swapPath,
        uint256 _collateralAmount
    ) external onlyVaultManager returns (uint256 _amountOut) {
        if (_collateralAddr == address(0)) {
            _collateralAddr = ISmartVaultManagerV3(manager).weth();
            IWETH(_collateralAddr).deposit{value: _collateralAmount}();
        }
        IERC20(_collateralAddr).safeIncreaseAllowance(_swapRouterAddress, _collateralAmount);
        _amountOut = ISwapRouter(_swapRouterAddress).exactInput(
            ISwapRouter.ExactInputParams({
                path: _swapPath,
                recipient: address(this),
                deadline: block.timestamp + 3600,
                amountIn: _collateralAmount,
                // minimum amount out should be at least usd value of collateral being swapped in
                amountOutMinimum: calculator.tokenToUSD(
                    ITokenManager(ISmartVaultManagerV3(manager).tokenManager()).getTokenIfExists(_collateralAddr),
                    _collateralAmount
                )
            })
        );
        IERC20(_collateralAddr).forceApprove(_swapRouterAddress, 0);
        uint256 _usdsBalance = USDs.balanceOf(address(this));
        minted -= _usdsBalance;
        USDs.burn(address(this), _usdsBalance);
    }

    function addUniqueHypervisor(address _hypervisor) private {
        for (uint256 i = 0; i < hypervisors.length; i++) {
            if (hypervisors[i] == _hypervisor) return;
        }
        hypervisors.push(_hypervisor);
    }

    function removeHypervisor(address _hypervisor) private {
        for (uint256 i = 0; i < hypervisors.length; i++) {
            if (hypervisors[i] == _hypervisor) {
                hypervisors[i] = hypervisors[hypervisors.length - 1];
                hypervisors.pop();
            }
        }
    }

    function significantCollateralDrop(
        uint256 _preCollateralValue,
        uint256 _postCollateralValue,
        uint256 _minCollateralPercentage
    ) private view returns (bool) {
        return _postCollateralValue
            < _minCollateralPercentage * _preCollateralValue / ISmartVaultManagerV3(manager).HUNDRED_PC();
    }

    function depositYield(
        bytes32 _symbol,
        uint256 _stablePercentage,
        uint256 _minCollateralPercentage,
        uint256 _deadline
    ) external onlyOwner withinTimestamp(_deadline) {
        if (_symbol == NATIVE) IWETH(ISmartVaultManagerV3(manager).weth()).deposit{value: address(this).balance}();
        address _token = getTokenisedAddr(_symbol);
        uint256 _balance = getAssetBalance(_token);
        if (_balance == 0) revert InvalidToken();
        IERC20(_token).safeIncreaseAllowance(ISmartVaultManagerV3(manager).yieldManager(), _balance);
        uint256 _preDepositCollateral = usdCollateral();
        (address _hypervisor1, address _hypervisor2) =
            ISmartVaultYieldManager(ISmartVaultManagerV3(manager).yieldManager()).deposit(_token, _stablePercentage);
        addUniqueHypervisor(_hypervisor1);
        if (_hypervisor2 != address(0)) addUniqueHypervisor(_hypervisor2);
        uint256 _postDepositCollateral = usdCollateral();
        if (
            _undercollateralised(_postDepositCollateral)
                || significantCollateralDrop(_preDepositCollateral, _postDepositCollateral, _minCollateralPercentage)
        ) revert Undercollateralised();
    }

    function withdrawYield(address _hypervisor, bytes32 _symbol, uint256 _minCollateralPercentage, uint256 _deadline)
        external
        onlyOwner
        withinTimestamp(_deadline)
    {
        address _token = getTokenisedAddr(_symbol);
        IERC20(_hypervisor).safeIncreaseAllowance(
            ISmartVaultManagerV3(manager).yieldManager(), IERC20(_hypervisor).balanceOf(address(this))
        );
        uint256 _preWithdrawCollateral = usdCollateral();
        ISmartVaultYieldManager(ISmartVaultManagerV3(manager).yieldManager()).withdraw(_hypervisor, _token);
        removeHypervisor(_hypervisor);
        if (_symbol == NATIVE) {
            IWETH(_token).withdraw(getAssetBalance(_token));
        }
        uint256 _postWithdrawCollateral = usdCollateral();
        if (
            _undercollateralised(_postWithdrawCollateral)
                || significantCollateralDrop(_preWithdrawCollateral, _postWithdrawCollateral, _minCollateralPercentage)
        ) revert Undercollateralised();
    }

    function yieldAssets() external view returns (YieldPair[] memory _yieldPairs) {
        _yieldPairs = new YieldPair[](hypervisors.length);
        for (uint256 i = 0; i < hypervisors.length; i++) {
            IHypervisor _hypervisor = IHypervisor(hypervisors[i]);
            uint256 _balance = _hypervisor.balanceOf(address(this));
            uint256 _hypervisorTotal = _hypervisor.totalSupply();
            (uint256 _underlyingTotal0, uint256 _underlyingTotal1) = _hypervisor.getTotalAmounts();

            _yieldPairs[i].hypervisor = hypervisors[i];
            _yieldPairs[i].token0 = _hypervisor.token0();
            _yieldPairs[i].token1 = _hypervisor.token1();
            _yieldPairs[i].amount0 = _balance * _underlyingTotal0 / _hypervisorTotal;
            _yieldPairs[i].amount1 = _balance * _underlyingTotal1 / _hypervisorTotal;
        }
    }

    function setOwner(address _newOwner) external onlyVaultManager {
        owner = _newOwner;
    }
}

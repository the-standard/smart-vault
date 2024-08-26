// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

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

    struct YieldPair { address hypervisor; address token0; uint256 amount0; address token1; uint256 amount1; }

    event CollateralRemoved(bytes32 symbol, uint256 amount, address to);
    event AssetRemoved(address token, uint256 amount, address to);
    event USDsMinted(address to, uint256 amount, uint256 fee);
    event USDsBurned(uint256 amount, uint256 fee);

    error InvalidUser();
    error VaultLiquidated();
    error Overrepay();
    error TransferError();
    error NotUndercollateralised();
    error Undercollateralised();
    error InvalidToken();

    constructor(bytes32 _native, address _manager, address _owner, address _usds, address _priceCalculator) {
        NATIVE = _native;
        owner = _owner;
        manager = _manager;
        USDs = IUSDs(_usds);
        calculator = IPriceCalculator(_priceCalculator);
    }

    modifier onlyVaultManager {
        if (msg.sender != manager) revert InvalidUser();
        _;
    }

    modifier onlyOwner {
        if (msg.sender != owner) revert InvalidUser();
        _;
    }

    modifier ifMinted(uint256 _amount) {
        if (minted < _amount) revert Overrepay();
        _;
    }

    modifier ifNotLiquidated {
        if (liquidated) revert VaultLiquidated();
        _;
    }

    function getTokenManager() private view returns (ITokenManager) {
        return ITokenManager(ISmartVaultManagerV3(manager).tokenManager());
    }

    function yieldVaultCollateral(ITokenManager.Token[] memory _acceptedTokens) private view returns (uint256 _usds) {
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
                if (_token0 == address(USDs) || _token1 == address(USDs)) {
                    // both USDs and its vault pair are $ stablecoins, but can be equivalent to $ in collateral
                    _usds += _underlying0 * 10 ** (18 - ERC20(_token0).decimals());
                    _usds += _underlying1 * 10 ** (18 - ERC20(_token1).decimals());
                } else {
                    for (uint256 j = 0; j < _acceptedTokens.length; j++) {
                        ITokenManager.Token memory _token = _acceptedTokens[j];
                        if (_token.addr == _token0) _usds += calculator.tokenToUSD(_token, _underlying0);
                        if (_token.addr == _token1) _usds += calculator.tokenToUSD(_token, _underlying1);
                    }
                }
            }
        }
    }
 
    function usdCollateral() private view returns (uint256 _usds) {
        ITokenManager tokenManager = ITokenManager(ISmartVaultManagerV3(manager).tokenManager());
        ITokenManager.Token[] memory acceptedTokens = tokenManager.getAcceptedTokens();
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            ITokenManager.Token memory _token = acceptedTokens[i];
            _usds += calculator.tokenToUSD(_token, getAssetBalance(_token.addr));
        }

        _usds += yieldVaultCollateral(acceptedTokens);
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
        return Status(address(this), minted, maxMintable(_collateral), _collateral,
            getAssets(), liquidated, version, vaultType);
    }

    function undercollateralised() public view returns (bool) {
        return minted > maxMintable(usdCollateral());
    }

    function liquidateNative() private {
        if (address(this).balance != 0) {
            (bool sent,) = payable(ISmartVaultManagerV3(manager).protocol()).call{value: address(this).balance}("");
            if (!sent) revert TransferError();
        }
    }

    function liquidateERC20(IERC20 _token) private {
        if (_token.balanceOf(address(this)) != 0) _token.safeTransfer(ISmartVaultManagerV3(manager).protocol(), _token.balanceOf(address(this)));
    }

    function liquidate() external onlyVaultManager {
        if (!undercollateralised()) revert NotUndercollateralised();
        liquidated = true;
        minted = 0;
        liquidateNative();
        ITokenManager.Token[] memory tokens = ITokenManager(ISmartVaultManagerV3(manager).tokenManager()).getAcceptedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].symbol != NATIVE) liquidateERC20(IERC20(tokens[i].addr));
        }
    }

    receive() external payable {}

    function canRemoveCollateral(ITokenManager.Token memory _token, uint256 _amount) private view returns (bool) {
        if (minted == 0) return true;
        uint256 usdValueToRemove = calculator.tokenToUSD(_token, _amount);
        uint256 _newCollateral = usdCollateral() - usdValueToRemove;
        return maxMintable(_newCollateral) >= minted;
    }

    function removeCollateralNative(uint256 _amount, address payable _to) external onlyOwner {
        if (!canRemoveCollateral(getTokenManager().getToken(NATIVE), _amount)) revert Undercollateralised();
        (bool sent,) = _to.call{value: _amount}("");
        if (!sent) revert TransferError();
        emit CollateralRemoved(NATIVE, _amount, _to);
    }

    function removeCollateral(bytes32 _symbol, uint256 _amount, address _to) external onlyOwner {
        ITokenManager.Token memory token = getTokenManager().getToken(_symbol);
        if (!canRemoveCollateral(token, _amount)) revert Undercollateralised();
        IERC20(token.addr).safeTransfer(_to, _amount);
        emit CollateralRemoved(_symbol, _amount, _to);
    }

    function removeAsset(address _tokenAddr, uint256 _amount, address _to) external onlyOwner {
        ITokenManager.Token memory token = getTokenManager().getTokenIfExists(_tokenAddr);
        if (token.addr == _tokenAddr && !canRemoveCollateral(token, _amount)) revert Undercollateralised();
        IERC20(_tokenAddr).safeTransfer(_to, _amount);
        emit AssetRemoved(_tokenAddr, _amount, _to);
    }

    function fullyCollateralised(uint256 _amount) private view returns (bool) {
        return minted + _amount <= maxMintable(usdCollateral());
    }

    function mint(address _to, uint256 _amount) external onlyOwner ifNotLiquidated {
        uint256 fee = _amount * ISmartVaultManagerV3(manager).mintFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        if (!fullyCollateralised(_amount + fee)) revert Undercollateralised();
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
        ITokenManager.Token[] memory tokens = ITokenManager(ISmartVaultManagerV3(manager).tokenManager()).getAcceptedTokens();
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].symbol == _symbol) _token = tokens[i];
        }
        if (_token.symbol == bytes32(0)) revert InvalidToken();
    }

    function getTokenisedAddr(bytes32 _symbol) private view returns (address) {
        ITokenManager.Token memory _token = getToken(_symbol);
        return _token.addr == address(0) ? ISmartVaultManagerV3(manager).weth() : _token.addr;
    }

    function executeNativeSwapAndFee(ISwapRouter.ExactInputSingleParams memory _params, uint256 _swapFee) private {
        (bool sent,) = payable(ISmartVaultManagerV3(manager).protocol()).call{value: _swapFee}("");
        if (!sent) revert TransferError();
        ISwapRouter(ISmartVaultManagerV3(manager).swapRouter()).exactInputSingle{value: _params.amountIn}(_params);
    }

    function executeERC20SwapAndFee(ISwapRouter.ExactInputSingleParams memory _params, uint256 _swapFee) private {
        IERC20(_params.tokenIn).safeTransfer(ISmartVaultManagerV3(manager).protocol(), _swapFee);
        IERC20(_params.tokenIn).safeApprove(ISmartVaultManagerV3(manager).swapRouter(), _params.amountIn);
        ISwapRouter(ISmartVaultManagerV3(manager).swapRouter()).exactInputSingle(_params);
        IERC20(_params.tokenIn).safeApprove(ISmartVaultManagerV3(manager).swapRouter(), 0);
        IWETH weth = IWETH(ISmartVaultManagerV3(manager).weth());
        // convert potentially received weth to eth
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance > 0) weth.withdraw(wethBalance);
    }

    function calculateMinimumAmountOut(bytes32 _inTokenSymbol, bytes32 _outTokenSymbol, uint256 _amount) private view returns (uint256) {
        ISmartVaultManagerV3 _manager = ISmartVaultManagerV3(manager);
        uint256 requiredCollateralValue = minted * _manager.collateralRate() / _manager.HUNDRED_PC();
        // add 1% min collateral buffer
        uint256 collateralValueMinusSwapValue = usdCollateral() - calculator.tokenToUSD(getToken(_inTokenSymbol), _amount * 101 / 100);
        return collateralValueMinusSwapValue >= requiredCollateralValue ?
            0 : calculator.USDToToken(getToken(_outTokenSymbol), requiredCollateralValue - collateralValueMinusSwapValue);
    }

    function swap(bytes32 _inToken, bytes32 _outToken, uint256 _amount, uint256 _requestedMinOut) external onlyOwner {
        uint256 swapFee = _amount * ISmartVaultManagerV3(manager).swapFeeRate() / ISmartVaultManagerV3(manager).HUNDRED_PC();
        address inToken = getTokenisedAddr(_inToken);
        uint256 minimumAmountOut = calculateMinimumAmountOut(_inToken, _outToken, _amount + swapFee);
        if (_requestedMinOut > minimumAmountOut) minimumAmountOut = _requestedMinOut;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: inToken,
                tokenOut: getTokenisedAddr(_outToken),
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp + 60,
                amountIn: _amount - swapFee,
                amountOutMinimum: minimumAmountOut,
                sqrtPriceLimitX96: 0
            });
        inToken == ISmartVaultManagerV3(manager).weth() ?
            executeNativeSwapAndFee(params, swapFee) :
            executeERC20SwapAndFee(params, swapFee);
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

    function significantCollateralDrop(uint256 _preCollateralValue, uint256 _postCollateralValue) private pure returns (bool) {
        return _postCollateralValue < 9 * _preCollateralValue / 10;
    }

    function depositYield(bytes32 _symbol, uint256 _stablePercentage) external onlyOwner {
        if (_symbol == NATIVE) IWETH(ISmartVaultManagerV3(manager).weth()).deposit{value: address(this).balance}();
        address _token = getTokenisedAddr(_symbol);
        uint256 _balance = getAssetBalance(_token);
        if (_balance == 0) revert InvalidToken();
        IERC20(_token).safeApprove(ISmartVaultManagerV3(manager).yieldManager(), _balance);
        uint256 _preDepositCollateral = usdCollateral();
        (address _hypervisor1, address _hypervisor2) = ISmartVaultYieldManager(ISmartVaultManagerV3(manager).yieldManager()).deposit(_token, _stablePercentage);
        addUniqueHypervisor(_hypervisor1);
        if (_hypervisor2 != address(0)) addUniqueHypervisor(_hypervisor2);
        if (undercollateralised() || significantCollateralDrop(_preDepositCollateral, usdCollateral())) revert Undercollateralised();
    }

    function withdrawYield(address _hypervisor, bytes32 _symbol) external onlyOwner {
        address _token = getTokenisedAddr(_symbol);
        IERC20(_hypervisor).safeApprove(ISmartVaultManagerV3(manager).yieldManager(), IERC20(_hypervisor).balanceOf(address(this)));
        uint256 _preWithdrawCollateral = usdCollateral();
        ISmartVaultYieldManager(ISmartVaultManagerV3(manager).yieldManager()).withdraw(_hypervisor, _token);
        removeHypervisor(_hypervisor);
        if (_symbol == NATIVE) {
            IWETH(_token).withdraw(getAssetBalance(_token));
        }
        if (undercollateralised() || significantCollateralDrop(_preWithdrawCollateral, usdCollateral())) revert Undercollateralised();
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

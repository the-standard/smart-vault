// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {Functions} from "@chainlink/contracts/src/v0.8/dev/functions/Functions.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/dev/functions/FunctionsClient.sol";
import {IRedeemable} from "contracts/interfaces/IRedeemable.sol";
import {ISmartVault} from "contracts/interfaces/ISmartVault.sol";
import {ISmartVaultManager} from "contracts/interfaces/ISmartVaultManager.sol";
import {ISmartVaultIndex} from "contracts/interfaces/ISmartVaultIndex.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";
import {IQuoter} from "contracts/interfaces/IQuoter.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";
import {IERC20} from
    "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AutoRedemption is AutomationCompatibleInterface, FunctionsClient, ConfirmedOwner {
    using Functions for Functions.Request;

    uint32 private constant MAX_REQ_GAS = 100_000;
    uint160 private constant TARGET_PRICE = 79228162514264337593543;
    bytes32 private lastRequestId;
    address private immutable smartVaultManager;
    IUniswapV3Pool private immutable pool;
    address private immutable smartVaultIndex;
    address private immutable swapRouter;
    address private immutable quoter;
    uint160 private immutable triggerPrice;
    uint64 public immutable subscriptionID;
    uint256 public immutable lastLegacyVaultID;
    mapping(address => address) hypervisorCollaterals;
    mapping(address => bytes) swapPaths;

    string source = "const { ethers } = await import('npm:ethers@6.10.0')"
        "const apiResponse = await Functions.makeHttpRequest({"
        "url: 'https://smart-vault-api.thestandard.io/redemption'" "});" "if (apiResponse.error) {"
        "throw Error('Request failed');" "}" "const { data } = apiResponse;"
        "const encoded = ethers.AbiCoder.defaultAbiCoder().encode(" "['uint256', 'address', 'uint256'],"
        "[data.tokenID, data.collateral, data.value]" ");" "return ethers.getBytes(encoded);";

    constructor(
        address _smartVaultManager,
        address _functionsRouter,
        address _pool,
        address _smartVaultIndex,
        address _swapRouter,
        address _quoter,
        uint160 _triggerPrice,
        uint64 _subscriptionID,
        uint256 _lastLegacyVaultID
    ) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) {
        smartVaultManager = _smartVaultManager;
        swapRouter = _swapRouter;
        quoter = _quoter;
        smartVaultIndex = _smartVaultIndex;
        // 0x8DEF4Db6697F4885bA4a3f75e9AdB3cEFCca6D6E
        pool = IUniswapV3Pool(_pool);
        // 77222060634363710668800
        triggerPrice = _triggerPrice;
        subscriptionID = _subscriptionID;
        lastLegacyVaultID = _lastLegacyVaultID;
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) {
        (uint160 sqrtPriceX96,,,,,,) = pool.slot0();
        upkeepNeeded = sqrtPriceX96 <= triggerPrice;
    }

    function _sendRequest() private {
        Functions.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        lastRequestId = sendRequest(req, subscriptionID, MAX_REQ_GAS);
    }

    function performUpkeep(bytes calldata performData) external {
        if (lastRequestId == bytes32(0)) {
            _sendRequest();
        }
    }

    function calculateUSDsToTargetPrice() private view returns (uint256 _usdc) {
        int24 _spacing = pool.tickSpacing();
        (uint160 _sqrtPriceX96, int24 _tick,,,,,) = pool.slot0();
        int24 _upperTick = _tick / _spacing * _spacing;
        int24 _lowerTick = _upperTick - _spacing;
        uint128 _liquidity = pool.liquidity();
        while (TickMath.getSqrtRatioAtTick(_lowerTick) < TARGET_PRICE) {
            uint256 _amount0;
            if (_tick > _lowerTick && _tick < _upperTick) {
                (uint256 _amount0,) = LiquidityAmounts.getAmountsForLiquidity(
                    _sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(_lowerTick),
                    TickMath.getSqrtRatioAtTick(_upperTick),
                    _liquidity
                );
            } else {
                (, int128 _liquidityNet,,,,,,) = pool.ticks(_lowerTick);
                _liquidity += uint128(_liquidityNet);
                (uint256 _amount0,) = LiquidityAmounts.getAmountsForLiquidity(
                    _sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(_lowerTick),
                    TickMath.getSqrtRatioAtTick(_upperTick),
                    _liquidity
                );
            }
            _usdc += _amount0;
            _lowerTick += _spacing;
            _upperTick += _spacing;
        }
    }

    function legacyAutoRedemption(
        address _smartVault,
        address _token,
        bytes memory _collateralToUSDCPath,
        uint256 _USDsTargetAmount,
        uint256 _estimatedCollateralValueUSD
    ) private {
        uint256 _collateralBalance = _token == address(0) ? _smartVault.balance : IERC20(_token).balanceOf(_smartVault);
        (uint256 _approxAmountInRequired,,,) =
            IQuoter(quoter).quoteExactOutput(_collateralToUSDCPath, _USDsTargetAmount);
        uint256 _amountIn = _approxAmountInRequired > _collateralBalance ? _collateralBalance : _approxAmountInRequired;
        ISmartVaultManager(smartVaultManager).vaultAutoRedemption(_smartVault, _token, _collateralToUSDCPath, _amountIn);
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        // TODO proper error handling
        // if (err) revert;
        if (requestId != lastRequestId) revert("wrong request");
        uint256 _USDsTargetAmount = calculateUSDsToTargetPrice();
        (uint256 _tokenID, address _token, uint256 _estimatedCollateralValueUSD) =
            abi.decode(response, (uint256, address, uint256));
        bytes memory _collateralToUSDCPath = swapPaths[_token];
        ISmartVaultManager.SmartVaultData memory _vaultData = ISmartVaultManager(smartVaultManager).vaultData(_tokenID);
        if (_USDsTargetAmount > _vaultData.status.minted) _USDsTargetAmount = _vaultData.status.minted;
        address _smartVault = _vaultData.status.vaultAddress;
        if (_tokenID <= lastLegacyVaultID) {
            legacyAutoRedemption(
                _smartVault, _token, _collateralToUSDCPath, _USDsTargetAmount, _estimatedCollateralValueUSD
            );
        } else {
            address _hypervisor;
            if (hypervisorCollaterals[_token] != address(0)) {
                _hypervisor = _token;
                _token = hypervisorCollaterals[_hypervisor];
            }
            IRedeemable(_smartVault).autoRedemption(
                _smartVault, quoter, _token, _collateralToUSDCPath, _USDsTargetAmount, _hypervisor
            );
        }
        lastRequestId = bytes32(0);
    }
}

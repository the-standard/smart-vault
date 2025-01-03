// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IRedeemable} from "contracts/interfaces/IRedeemable.sol";
import {ISmartVaultManager} from "contracts/interfaces/ISmartVaultManager.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";
import {IQuoter} from "contracts/interfaces/IQuoter.sol";
import {LiquidityMath} from "src/uniswap/LiquidityMath.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";
import {IERC20} from
    "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AutoRedemption is AutomationCompatibleInterface, FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    uint32 private constant MAX_REQ_GAS = 300000;
    uint160 private constant TARGET_PRICE = 79228162514264337593543;
    uint32 private constant TWAP_INTERVAL = 1800;
    uint256 private constant ENCODED_API_RESPONSE_LENGTH = 64;

    bytes32 private lastRequestId;
    bytes32 private immutable donID;
    address private immutable smartVaultManager;
    IUniswapV3Pool private immutable pool;
    address private immutable swapRouter;
    address private immutable quoter;
    uint160 private immutable triggerPrice;
    uint64 public immutable subscriptionID;
    uint256 public immutable lastLegacyVaultID;
    mapping(address => address) hypervisorCollaterals;
    mapping(address => SwapPath) swapPaths;

    struct SwapPath {
        bytes input;
        bytes output;
    }

    event AutoRedemption(address indexed vault, address indexed token, uint256 usdsRedeemed);

    string private constant source =
        "const { ethers } = await import('npm:ethers@6.10.0'); const apiResponse = await Functions.makeHttpRequest({ url: 'https://smart-vault-api.thestandard.io/redemption' }); if (apiResponse.error) { throw Error('Request failed'); } const { data } = apiResponse; const encoded = ethers.AbiCoder.defaultAbiCoder().encode(['uint256', 'address'], [data.tokenID, data.collateral]); return ethers.getBytes(encoded)";

    constructor(
        address _smartVaultManager,
        address _functionsRouter,
        bytes32 _donID,
        address _pool,
        address _swapRouter,
        address _quoter,
        uint160 _triggerPrice,
        uint64 _subscriptionID,
        uint256 _lastLegacyVaultID
    ) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) {
        smartVaultManager = _smartVaultManager;
        donID = _donID;
        swapRouter = _swapRouter;
        quoter = _quoter;
        // 0x8DEF4Db6697F4885bA4a3f75e9AdB3cEFCca6D6E
        pool = IUniswapV3Pool(_pool);
        // around .97-.98
        triggerPrice = _triggerPrice;
        subscriptionID = _subscriptionID;
        lastLegacyVaultID = _lastLegacyVaultID;
    }

    function poolTWAP() private returns (uint160) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = 0;
        secondsAgo[1] = TWAP_INTERVAL;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);

        int56 tickCumulativeDiff = tickCumulatives[0] - tickCumulatives[1];
        int24 twapTick = int24(tickCumulativeDiff / int56(int32(TWAP_INTERVAL)));
        return TickMath.getSqrtRatioAtTick(twapTick);
    }

    function redemptionRequired() private returns (bool) {
        return poolTWAP() <= triggerPrice;
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = redemptionRequired();
    }

    function triggerRequest() private {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionID, MAX_REQ_GAS, donID);
    }

    function performUpkeep(bytes calldata performData) external {
        if (lastRequestId == bytes32(0) && redemptionRequired()) {
            triggerRequest();
        }
    }

    function calculateUSDsToTargetPrice() private view returns (uint256 _usds) {
        int24 _spacing = pool.tickSpacing();
        (uint160 _sqrtPriceX96, int24 _tick,,,,,) = pool.slot0();
        int24 _upperTick = _tick / _spacing * _spacing;
        int24 _lowerTick = _upperTick - _spacing;
        uint128 _liquidity = pool.liquidity();
        while (TickMath.getSqrtRatioAtTick(_lowerTick) < TARGET_PRICE) {
            if (_lowerTick > _tick) {
                (, int128 _liquidityNet,,,,,,) = pool.ticks(_lowerTick);
                _liquidity = LiquidityMath.addDelta(_liquidity, _liquidityNet);
            }
            (uint256 _amount0,) = LiquidityAmounts.getAmountsForLiquidity(
                _sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(_lowerTick),
                TickMath.getSqrtRatioAtTick(_upperTick),
                _liquidity
            );
            _usds += _amount0;
            _lowerTick += _spacing;
            _upperTick += _spacing;
        }
    }

    function legacyAutoRedemption(address _smartVault, address _token, uint256 _USDsTargetAmount)
        private
        returns (uint256)
    {
        SwapPath memory _collateralToUSDsPath = swapPaths[_token];
        uint256 _collateralBalance = _token == address(0) ? _smartVault.balance : IERC20(_token).balanceOf(_smartVault);
        try IQuoter(quoter).quoteExactOutput(_collateralToUSDsPath.output, _USDsTargetAmount) returns (
            uint256 amountInRequired,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        ) {
            uint256 _amountIn = amountInRequired > _collateralBalance ? _collateralBalance : amountInRequired;
            try ISmartVaultManager(smartVaultManager).vaultAutoRedemption(
                _smartVault, _token, _collateralToUSDsPath.input, _amountIn
            ) returns (uint256 _usdsRedeemed) {
                return _usdsRedeemed;
            } catch {}
        } catch {}
    }

    function runAutoRedemption(bytes memory response)
        private
        returns (address _smartVault, address _collateralToken, uint256 _usdsRedeemed)
    {
        uint256 _USDsTargetAmount = calculateUSDsToTargetPrice();
        if (_USDsTargetAmount > 0) {
            (uint256 _tokenID, address _token) = abi.decode(response, (uint256, address));
            try ISmartVaultManager(smartVaultManager).vaultData(_tokenID) returns (
                ISmartVaultManager.SmartVaultData memory _vaultData
            ) {
                if (_USDsTargetAmount > _vaultData.status.minted) _USDsTargetAmount = _vaultData.status.minted;
                _smartVault = _vaultData.status.vaultAddress;
                if (_tokenID <= lastLegacyVaultID) {
                    _usdsRedeemed = legacyAutoRedemption(_smartVault, _token, _USDsTargetAmount);
                } else {
                    address _hypervisor;
                    if (hypervisorCollaterals[_token] != address(0)) {
                        _hypervisor = _token;
                        _token = hypervisorCollaterals[_hypervisor];
                    }
                    bytes memory _collateralToUSDsPath = swapPaths[_token].input;
                    try IRedeemable(_smartVault).autoRedemption(
                        swapRouter, quoter, _token, _collateralToUSDsPath, _USDsTargetAmount, _hypervisor
                    ) returns (uint256 _redeemed) {
                        _usdsRedeemed = _redeemed;
                    } catch {}
                }
                _collateralToken = _token;
            } catch {}
        }
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (requestId == lastRequestId && response.length == ENCODED_API_RESPONSE_LENGTH && redemptionRequired()) {
            (address _smartVault, address _token, uint256 _usdsRedeemed) = runAutoRedemption(response);
            if (_usdsRedeemed > 0) emit AutoRedemption(_smartVault, _token, _usdsRedeemed);
        }
        lastRequestId = bytes32(0);
    }

    function setHypervisorCollateral(address _hypervisor, address _collateral) external onlyOwner {
        hypervisorCollaterals[_hypervisor] = _collateral;
    }

    function setSwapPath(address _token, bytes memory _inputPath, bytes memory _outputPath) external onlyOwner {
        swapPaths[_token] = SwapPath(_inputPath, _outputPath);
    }
}

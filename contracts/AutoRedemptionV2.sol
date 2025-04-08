// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IQuoter} from "contracts/interfaces/IQuoter.sol";
import {IRedeemable} from "contracts/interfaces/IRedeemable.sol";
import {ISmartVaultManager} from "contracts/interfaces/ISmartVaultManager.sol";
import {ISmartVaultYieldManager} from "contracts/interfaces/ISmartVaultYieldManager.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";
import {LiquidityMath} from "src/uniswap/LiquidityMath.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {IERC20} from
    "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract AutoRedemptionV2 is AutomationCompatibleInterface, FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    uint32 private constant MAX_REQ_GAS = 300000;
    uint32 private constant TWAP_INTERVAL = 1800;
    uint256 private constant ENCODED_API_RESPONSE_LENGTH = 96;
    uint160 private constant TARGET_PRICE = 79228162514264337593543;

    bytes32 private immutable donID;
    uint64 public immutable subscriptionID;
    IUniswapV3Pool private immutable pool;
    address private immutable smartVaultManager;
    address private immutable yieldManager;
    uint256 public immutable lastLegacyVaultID;
    address private immutable quoter;
    address private immutable swapRouter;

    bytes32 private lastRequestId;
    bool public paused;
    uint256 public dataReceivedAt;
    uint256 public tokenID;
    address public token;
    address public hypervisor;
    uint160 private triggerPrice;
    mapping(address => SwapPath) swapPaths;

    struct SwapPath {
        bytes input;
        bytes output;
    }

    event AutoRedemption(address indexed vault, address indexed token, uint256 usdsRedeemed);

    string private constant source =
        "const { ethers } = await import('npm:ethers@6.10.0'); const apiResponse = await Functions.makeHttpRequest({ url: 'https://smart-vault-api.thestandard.io/redemption' }); if (apiResponse.error) { throw Error('Request failed'); } const { data } = apiResponse; const encoded = ethers.AbiCoder.defaultAbiCoder().encode(['uint256', 'address', 'address'], [data.tokenID, data.collateral, data.hypervisor]); return ethers.getBytes(encoded)";

    constructor(
        address _functionsRouter,
        bytes32 _donID,
        uint64 _subscriptionID,
        address _pool,
        uint160 _triggerPrice,
        address _smartVaultManager,
        address _yieldManager,
        uint256 _lastLegacyVaultID,
        address _quoter,
        address _swapRouter
    ) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) {
        donID = _donID;
        subscriptionID = _subscriptionID;
        pool = IUniswapV3Pool(_pool);
        triggerPrice = _triggerPrice;
        smartVaultManager = _smartVaultManager;
        yieldManager = _yieldManager;
        lastLegacyVaultID = _lastLegacyVaultID;
        quoter = _quoter;
        swapRouter = _swapRouter;
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

    function poolBelowTriggerPrice() private returns (bool) {
        return poolTWAP() <= triggerPrice;
    }

    function shouldRun() private returns (bool) {
        return !paused && poolBelowTriggerPrice() && lastRequestId == bytes32(0);
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = shouldRun();
    }

    function triggerRequest() private {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionID, MAX_REQ_GAS, donID);
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

    function validData(ISmartVaultManager.SmartVaultData memory _vaultData)
        private
        returns (bool)
    {
        if (_vaultData.status.vaultAddress == address(0)) return false;
        for (uint256 i = 0; i < _vaultData.status.collateral.length; i++) {
            if (_vaultData.status.collateral[i].token.addr == token) {
                return (
                    hypervisor == address(0)
                        || ISmartVaultYieldManager(yieldManager).getHypervisorForCollateral(token) == hypervisor
                );
            }
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
            // worth leaving a margin here, causing problems with small decimal tokens
            _amountIn = _amountIn * 99 / 100;
            try ISmartVaultManager(smartVaultManager).vaultAutoRedemption(
                _smartVault, _token, _collateralToUSDsPath.input, _amountIn
            ) returns (uint256 _usdsRedeemed) {
                return _usdsRedeemed;
            } catch {}
        } catch {}
    }

    function autoRedemption(address _smartVault, uint256 _USDsTargetAmount) private returns (uint256) {
        SwapPath memory _collateralToUSDsPaths = swapPaths[token];
        try IRedeemable(_smartVault).autoRedemption(
            swapRouter,
            quoter,
            token,
            _USDsTargetAmount,
            _collateralToUSDsPaths.input,
            _collateralToUSDsPaths.output,
            hypervisor
        ) returns (uint256 _redeemed) {
            return _redeemed;
        } catch {}
    }

    function runAutoRedemption()
        private
        returns (address _smartVault, uint256 _usdsRedeemed)
    {
        uint256 _USDsTargetAmount = calculateUSDsToTargetPrice();
        if (_USDsTargetAmount > 0) {
            try ISmartVaultManager(smartVaultManager).vaultData(tokenID) returns (
                ISmartVaultManager.SmartVaultData memory _vaultData
            ) {
                if (validData(_vaultData)) {
                    if (_USDsTargetAmount > _vaultData.status.minted) _USDsTargetAmount = _vaultData.status.minted;
                    _smartVault = _vaultData.status.vaultAddress;
                    if (tokenID <= lastLegacyVaultID) {
                        _usdsRedeemed = legacyAutoRedemption(_smartVault, token, _USDsTargetAmount);
                    } else {
                        _usdsRedeemed = autoRedemption(_smartVault, _USDsTargetAmount);
                    }
                }
            } catch {}
        }
    }

    function performUpkeep(bytes calldata performData) external {
        if (shouldRun()) {
            if ((block.timestamp - dataReceivedAt) > 30 minutes) {
                triggerRequest();
            } else {
                (address _smartVault, uint256 _usdsRedeemed) = runAutoRedemption();
                if (_usdsRedeemed == 0) {
                    paused = true;
                } else {
                    emit AutoRedemption(_smartVault, token, _usdsRedeemed);
                    dataReceivedAt = 0;
                    tokenID = 0;
                    token = address(0);
                    hypervisor = address(0);
                }
            }
        }
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        if (requestId == lastRequestId && response.length == ENCODED_API_RESPONSE_LENGTH) {
            (tokenID, token, hypervisor) = abi.decode(response, (uint256, address, address));
            dataReceivedAt = block.timestamp;
        }
        lastRequestId = bytes32(0);
    }

    function togglePause() external onlyOwner {
        paused = !paused;
    }

    function setSwapPath(address _token, bytes memory _inputPath, bytes memory _outputPath) external onlyOwner {
        swapPaths[_token] = SwapPath(_inputPath, _outputPath);
    }

    function setTriggerPrice(uint160 _triggerPrice) external onlyOwner {
        triggerPrice = _triggerPrice;
    }
}

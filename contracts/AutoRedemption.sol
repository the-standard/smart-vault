// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {Functions} from "@chainlink/contracts/src/v0.8/dev/functions/Functions.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/dev/functions/FunctionsClient.sol";
import {ISmartVaultManagerV3} from "contracts/interfaces/ISmartVaultManagerV3.sol";
import {IUniswapV3Pool} from "contracts/interfaces/IUniswapV3Pool.sol";
import {IQuoter} from "contracts/interfaces/IQuoter.sol";
import {TickMath} from "src/uniswap/TickMath.sol";
import {LiquidityAmounts} from "src/uniswap/LiquidityAmounts.sol";

contract AutoRedemption is AutomationCompatibleInterface, FunctionsClient, ConfirmedOwner {
    using Functions for Functions.Request;

    uint32 private constant MAX_REQ_GAS = 100_000;
    uint160 private constant TARGET_PRICE = 79228162514264337593543;
    IUniswapV3Pool private immutable pool;
    uint160 private immutable triggerPrice;
    bytes32 private lastRequestId;
    uint64 public immutable subscriptionID;
    address private immutable smartVaultManager;
    mapping(address => address) hypervisorCollaterals;
    mapping(address => bytes) swapPaths;

    string source =
        "const { ethers } = await import('npm:ethers@6.10.0')"
        "const apiResponse = await Functions.makeHttpRequest({"
            "url: 'https://smart-vault-api.thestandard.io/redemption'"
        "});"
        "if (apiResponse.error) {"
            "throw Error('Request failed');"
        "}"
        "const { data } = apiResponse;"
        "const encoded = ethers.AbiCoder.defaultAbiCoder().encode("
            "['uint256', 'address', 'uint256'],"
            "[data.tokenID, data.collateral, data.value]"
        ");"
        "return ethers.getBytes(encoded);";

    constructor(address _smartVaultManager, address _functionsRouter, address _pool, uint160 _triggerPrice, uint64 _subscriptionID) FunctionsClient(_functionsRouter) ConfirmedOwner(msg.sender) {
        smartVaultManager = _smartVaultManager;
        // 0x8DEF4Db6697F4885bA4a3f75e9AdB3cEFCca6D6E
        pool = IUniswapV3Pool(_pool);
        // 77222060634363710668800
        triggerPrice = _triggerPrice;
        subscriptionID = _subscriptionID;
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

    function calculateUSDCToTargetPrice() private view returns (uint256 _usdc) {
        int24 _spacing = pool.tickSpacing();
        (uint160 _sqrtPriceX96,int24 _tick,,,,,) = pool.slot0();
        int24 _upperTick = _tick / _spacing * _spacing;
        int24 _lowerTick = _upperTick - _spacing;
        uint128 _liquidity = pool.liquidity();
        while (TickMath.getSqrtRatioAtTick(_lowerTick) < TARGET_PRICE) {
            uint256 _amount0;
            if (_tick > _lowerTick && _tick < _upperTick) {
                (uint256 _amount0,) =  LiquidityAmounts.getAmountsForLiquidity(
                    _sqrtPriceX96, TickMath.getSqrtRatioAtTick(_lowerTick), TickMath.getSqrtRatioAtTick(_upperTick), _liquidity
                );
            } else {
                (,int128 _liquidityNet,,,,,,) = pool.ticks(_lowerTick);
                _liquidity += uint128(_liquidityNet);
                (uint256 _amount0,) =  LiquidityAmounts.getAmountsForLiquidity(
                    _sqrtPriceX96, TickMath.getSqrtRatioAtTick(_lowerTick), TickMath.getSqrtRatioAtTick(_upperTick), _liquidity
                );
            }
            _usdc += _amount0;
            _lowerTick += _spacing;
            _upperTick += _spacing;
        }
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // TODO proper error handling
        // if (err) revert;
        if (requestId != lastRequestId) revert("wrong request");
        (uint256 _tokenID, address _token, uint256 _estimatedCollateralValueUSD) = abi.decode(response,(uint256,address,uint256));
        address _hypervisor;
        if (hypervisorCollaterals[_token] != address(0)) {
            _hypervisor = _token;
            _token = hypervisorCollaterals[_token];
        } else {

        }
        bytes memory collateralToUSDCPath = swapPaths[_token];
        uint256 USDCTargetAmount = calculateUSDCToTargetPrice();
        uint256 _collateralSwapAmount;
        // figure out how to calculate the _collateralSwapAmount
        // existing vaults need params address _swapRouterAddress, address _collateralAddr, bytes memory _swapPath, uint256 _collateralAmount
        // we don't know underlying collateral value of hypervisor positions ... what can we calculate in api?
        if (USDCTargetAmount > _estimatedCollateralValueUSD) {
            // swap all the (underlying) vault's balance of given collateral
        } else {
            // swap a part of user's collateral ... need to figure out calculation
        }
        ISmartVaultManagerV3(smartVaultManager).vaultAutoRedemption(_tokenID, _token, collateralToUSDCPath, _collateralSwapAmount, _hypervisor);
        lastRequestId = bytes32(0);
    }
}

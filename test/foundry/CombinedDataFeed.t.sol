// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdError, console} from "forge-std/Test.sol";
import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";
import {CombinedDataFeed} from "src/CombinedDataFeed.sol";

contract CombinedDataFeedTest is Test {
    CombinedDataFeed combinedDataFeed;

    function setUp() public {
        ChainlinkMock _wstETHETHMock = new ChainlinkMock("wstETH / ETH");
        _wstETHETHMock.setDecimals(18);
        // 1.2 eth per wsteth
        _wstETHETHMock.setPrice(12e17);
        ChainlinkMock _ETHUSDMock = new ChainlinkMock("ETH / USD");
        // $2500 per eth
        _ETHUSDMock.setPrice(2500e8);
        combinedDataFeed = new CombinedDataFeed(address(_wstETHETHMock), address(_ETHUSDMock));
    }

    function test_latestRoundData() public {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            combinedDataFeed.latestRoundData();
        // $3000 per wsteth
        assertEq(answer, 3000e8);
        assertGt(roundId, 0);
        assertGt(startedAt, 0);
        assertGt(updatedAt, 0);
        assertGt(answeredInRound, 0);
    }
}

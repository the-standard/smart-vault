// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@chimera/Hevm.sol";

import {SmartVaultYieldManagerFixture} from "./SmartVaultYieldManagerFixture.sol";
import {TokenManagerFixture} from "./TokenManagerFixture.sol";

import {PriceCalculator} from "src/PriceCalculator.sol";
import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";

import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";
import {MockNFTMetadataGenerator} from "src/test_utils/MockNFTMetadataGenerator.sol";

contract SmartVaultManagerFixture is TokenManagerFixture {
    SmartVaultManagerV6 smartVaultManager;
    SmartVaultIndex smartVaultIndex;
    PriceCalculator priceCalculator;

    function setUp() public virtual override {
        super.setUp();

        ChainlinkMock clUsdcUsd = new ChainlinkMock("USDC / USD");
        clUsdcUsd.setPrice(1e8);
        ChainlinkMock sequencerUptimeFeed = new ChainlinkMock("USDC / USD");
        sequencerUptimeFeed.setStartedAt(block.timestamp - 2 hours);
        priceCalculator = new PriceCalculator(NATIVE, address(clUsdcUsd), address(sequencerUptimeFeed));
        SmartVaultDeployerV4 smartVaultDeployer = new SmartVaultDeployerV4(NATIVE, address(priceCalculator));
        smartVaultIndex = new SmartVaultIndex();

        MockNFTMetadataGenerator nftMetadataGenerator = new MockNFTMetadataGenerator();

        smartVaultManager = new SmartVaultManagerV6();

        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.initialize(
            COLLATERAL_RATE,
            PROTOCOL_FEE_RATE,
            address(usds),
            PROTOCOL,
            address(tokenManager),
            address(smartVaultDeployer),
            address(smartVaultIndex),
            address(nftMetadataGenerator),
            // address(yieldManager),
            VAULT_LIMIT
        );
        // address(uniswapRouter),
        // address(weth)
        // vm.startPrank(sender) is not yet fully supported by invariant fuzzers, so we have to duplicate vm.prank
        // NOTE: the yield manager is set in the SmartVaultYieldManagerFixture
        // vm.prank(VAULT_MANAGER_OWNER);
        // smartVaultManager.setYieldManager(address(yieldManager));
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setSwapRouter(address(uniswapRouter));
        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.setWethAddress(address(weth));

        // the foundry deployment address is the owner of the smartVaultIndex
        smartVaultIndex.setVaultManager(address(smartVaultManager));
        // the usds mock does not have any ownership access controls, only default admin and minter/burner roles
        usds.grantRole(usds.DEFAULT_ADMIN_ROLE(), address(smartVaultManager));
        usds.grantRole(usds.BURNER_ROLE(), address(smartVaultManager));
    }
}

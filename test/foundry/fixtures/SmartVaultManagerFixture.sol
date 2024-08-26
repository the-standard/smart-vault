// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {SmartVaultYieldManagerFixture} from "./SmartVaultYieldManagerFixture.sol";

import {ChainlinkMock} from "src/test_utils/ChainlinkMock.sol";

import {SmartVaultDeployerV4} from "src/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "src/SmartVaultIndex.sol";
import {SmartVaultManagerV6} from "src/SmartVaultManagerV6.sol";
import {TokenManager} from "src/TokenManager.sol";
import {NFTMetadataGenerator} from "src/nfts/NFTMetadataGenerator.sol";

contract SmartVaultManagerFixture is SmartVaultYieldManagerFixture {
    SmartVaultManagerV6 internal smartVaultManager;

    function setUp() public virtual override {
        super.setUp();

        ChainlinkMock clNativeUsd = new ChainlinkMock("ETH/USD");
        TokenManager tokenManager = new TokenManager(NATIVE, address(clNativeUsd));
        SmartVaultDeployerV4 smartVaultDeployer = new SmartVaultDeployerV4(NATIVE);
        SmartVaultIndex smartVaultIndex = new SmartVaultIndex();
        NFTMetadataGenerator nftMetadataGenerator = new NFTMetadataGenerator();

        smartVaultManager = new SmartVaultManagerV6();

        vm.prank(VAULT_MANAGER_OWNER);
        smartVaultManager.initialize(
            COLLATERAL_RATE,
            FEE_RATE,
            address(usds),
            PROTOCOL,
            LIQUIDATOR,
            address(tokenManager),
            address(smartVaultDeployer),
            address(smartVaultIndex),
            address(nftMetadataGenerator),
            address(yieldManager),
            USER_VAULT_LIMIT,
            address(uniswapRouter),
            address(weth)
        );

        // the foundry deployment address is the owner of the smartVaultIndex
        smartVaultIndex.setVaultManager(address(smartVaultManager));
        // the usds mock does not have any ownership access controls
        usds.grantRole(usds.DEFAULT_ADMIN_ROLE(), address(smartVaultManager));
    }
}

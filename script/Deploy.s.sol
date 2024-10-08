// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Script} from "forge-std/Script.sol";
import {ChainlinkMock} from "../contracts/test_utils/ChainlinkMock.sol";
import {IUSDs} from "../contracts/interfaces/IUSDs.sol";
import {NFTMetadataGenerator} from "../contracts/NFTMetadataGenerator.sol";
import {PriceCalculator} from "../contracts/PriceCalculator.sol";
import {SmartVaultDeployerV4} from "../contracts/SmartVaultDeployerV4.sol";
import {SmartVaultIndex} from "../contracts/SmartVaultIndex.sol";
import {SmartVaultManagerV6} from "../contracts/SmartVaultManagerV6.sol";
import {Upgrades} from "lib/openzeppelin-foundry-upgrades/Upgrades.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ChainlinkMock clUsdcUsd = new ChainlinkMock("USDC / USD");
        clUsdcUsd.setPrice(100000000);
        ChainlinkMock uptimeFeed = new ChainlinkMock("Uptime Feed");
        uptimeFeed.setStartedAt(block.timestamp - 2 hours);
        PriceCalculator calculator = new PriceCalculator(bytes32("ETH"), address(clUsdcUsd), address(uptimeFeed));
        SmartVaultDeployerV4 deployer = new SmartVaultDeployerV4(bytes32("ETH"), address(calculator));
        SmartVaultIndex index = new SmartVaultIndex();
        NFTMetadataGenerator generator = new NFTMetadataGenerator();
        IUSDs usds = IUSDs(0x0173184A51CF807Cc386B3F5Dc5689Cae09B81fb);

        address proxy = Upgrades.deployTransparentProxy(
            "SmartVaultManagerV6.sol",
            msg.sender,
            abi.encodeCall(MyContract.initialize, (
                110000,
                500,
                address(usds), // usds
                0xCa17e2A2264f4Cf721a792d771A4021c37538049, // protocol
                0x18f413879A00Db35A4Ea22300977924E613F3D88, // token manager
                address(deployer),
                address(index), // protocol
                address(generator),
                1000
            ))
        );

        index.setVaultManager(proxy);

        usds.grantRole(usds.DEFAULT_ADMIN_ROLE(), proxy);
        usds.grantRole(usds.BURNER_ROLE(), proxy);
        
        // set weth address
        // set swap router
        // set yield manager

        vm.stopBroadcast();
    }
}
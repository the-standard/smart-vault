// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "contracts/test_utils/SmartVaultV4Legacy.sol";
import "contracts/PriceCalculator.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";

contract SmartVaultDeployerV4Legacy is ISmartVaultDeployer {
    bytes32 private immutable NATIVE;
    address private immutable priceCalculator;

    constructor(bytes32 _native, address _priceCalculator) {
        NATIVE = _native;
        priceCalculator = _priceCalculator;
    }

    function deploy(address _manager, address _owner, address _usds) external returns (address) {
        return address(new SmartVaultV4Legacy(NATIVE, _manager, _owner, _usds, priceCalculator));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/test_utils/SmartVaultV2.sol";
import "contracts/PriceCalculator.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";

contract SmartVaultDeployerV2 is ISmartVaultDeployer {    
    address private immutable priceCalculator;

    constructor(address _clEurUsd) {
        priceCalculator = address(new PriceCalculator(_clEurUsd));
    }
            
    // TODO do we need to protect this function? probably not?
    function deploy(address _manager, address _owner, address _seuro) external returns (address) {
        return address(new SmartVaultV2(_manager, _owner, _seuro, priceCalculator));
    }
}

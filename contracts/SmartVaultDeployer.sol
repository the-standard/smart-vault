// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/SmartVault.sol";
import "contracts/PriceCalculator.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";

contract SmartVaultDeployer is ISmartVaultDeployer {    
    address private immutable priceCalculator;

    constructor(address _clEurUsd) {
        priceCalculator = address(new PriceCalculator(_clEurUsd));
    }
            
    function deploy(address _manager, address _owner, address _seuro) external returns (address) {
        return address(new SmartVault(_manager, _owner, _seuro, priceCalculator));
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/SmartVault.sol";
import "contracts/PriceCalculator.sol";
import "contracts/interfaces/ISmartVaultDeployer.sol";

contract SmartVaultDeployer is ISmartVaultDeployer {    
    bytes32 private immutable NATIVE;
    address private immutable priceCalculator;

    constructor(bytes32 _native, address _clEurUsd) {
        NATIVE = _native;
        priceCalculator = address(new PriceCalculator(_native, _clEurUsd));
    }
    
    function deploy(address _manager, address _owner, address _seuro) external returns (address) {
        return address(new SmartVault(NATIVE, _manager, _owner, _seuro, priceCalculator));
    }
}

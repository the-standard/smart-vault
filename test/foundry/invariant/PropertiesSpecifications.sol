// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract PropertiesSpecifications {
    string internal constant ADD_COLLATERAL_01 = "ADD_COLLATERAL_01: Deposits increase Smart Vault collateral value"; // TODO

    string internal constant REMOVE_COLLATERAL_NATIVE_01 = "REMOVE_COLLATERAL_NATIVE_01: Native withdrawals decrease Smart Vault collateral value";
    string internal constant REMOVE_COLLATERAL_NATIVE_02 = "REMOVE_COLLATERAL_NATIVE_02: Native withdrawals decrease the Smart Vault balance";
    string internal constant REMOVE_COLLATERAL_NATIVE_03 = "REMOVE_COLLATERAL_NATIVE_03: Native withdrawals increase the recipient balance";
    
    string internal constant REMOVE_COLLATERAL_01 = "REMOVE_COLLATERAL_01: Collateral withdrawals decrease Smart Vault collateral value";
    string internal constant REMOVE_COLLATERAL_02 = "REMOVE_COLLATERAL_02: Collateral withdrawals decrease the Smart Vault balance";
    string internal constant REMOVE_COLLATERAL_03 = "REMOVE_COLLATERAL_03: Collateral withdrawals increase the recipient balance";
    
    string internal constant REMOVE_ASSET_01 = "REMOVE_ASSET_01: Collateral asset withdrawals decrease the Smart Vault collateral value";
    string internal constant REMOVE_ASSET_02 = "REMOVE_ASSET_02: Collateral asset withdrawals decrease the Smart Vault balance";
    string internal constant REMOVE_ASSET_03 = "REMOVE_ASSET_03: Collateral asset withdrawals increase the recipient balance";
    string internal constant REMOVE_ASSET_04 = "REMOVE_ASSET_04: Collateral asset withdrawals only succeed if the Smart Vault remains overcollateralised";
    string internal constant REMOVE_ASSET_05 = "REMOVE_ASSET_05: Removes non-collateral assets without affecting the Smart Vault collateral value";
    string internal constant REMOVE_ASSET_06 = "REMOVE_ASSET_06: Non-collateral asset withdrawals decrease the Smart Vault balance";
    string internal constant REMOVE_ASSET_07 = "REMOVE_ASSET_07: Non-collateral asset withdrawals increase the recipient balance";

    string internal constant MINT_01 = "MINT_01: Minting increases recipient's USDs balance";
    string internal constant MINT_02 = "MINT_02: Minting increases the Smart Vault's minted USDs state";
    string internal constant MINT_03 = "MINT_03: Minted state cannot exceed max mintable";
    string internal constant MINT_04 = "MINT_04: Minting cannot immediately make the Smart Vault undercollateralised";

    string internal constant BURN_01 = "BURN_01: Burn decreases the caller's USDs balance";
    string internal constant BURN_02 = "BURN_02: Burn decreases the minted state";

    string internal constant SWAP_01 = "SWAP_01: Swaps cannot leave the Smart Vault undercollateralised";
    string internal constant SWAP_02 = "SWAP_02: Swaps cannot increase the Smart Vault's collateral value";
    string internal constant SWAP_03 = "SWAP_03: Swaps deacrease the Smart Vault's input token balance";
    string internal constant SWAP_04 = "SWAP_04: Swaps increase the Smart Vault's output token balance";

    string internal constant LIQUIDATE_01 = "LIQUIDATE_01: Liquidate only succeeds if the Smart Vault is undercollateralised";
    string internal constant LIQUIDATE_02 = "LIQUIDATE_02: Liquidate increases the protocol's collateral";
    string internal constant LIQUIDATE_03 = "LIQUIDATE_03: Liquidate clears the Smart Vault's minted USDs state";
    string internal constant LIQUIDATE_04 = "LIQUIDATE_04: Liquidate marks the Smart Vault as liquidated";
    string internal constant LIQUIDATE_05 = "LIQUIDATE_05: Liquidate decreases the Smart Vault's max mintable to zero";

    string internal constant DEPOSIT_YIELD_01 = "DEPOSIT_YIELD_01: Deposits cannot leave the Smart Vault undercollateralised";

    string internal constant WITHDRAW_YIELD_01 = "WITHDRAW_YIELD_01: Withdrawals cannot leave the Smart Vault undercollateralised";

    string internal constant UNDERCOLLATERALISED_01 =
        "UNDERCOLLATERALISED_01: A Smart Vault cannot execute an operation that leaves it undercollateralised";
    string internal constant UNDERCOLLATERALISED_02 = "UNDERCOLLATERALISED_02: Undercollateralised Smart Vaults cannot mint USDs"; // TODO

    string internal constant FEES_01 =
        "FEES_01: Fees are take on minting and burning USDs";
    string internal constant FEES_02 = "FEES_02: Fees are taken on yield withdrawals";

    string internal constant DOS = "DOS: Denial of Service";

    string internal constant REVERTS = "REVERTS: Actions behave as expected under dependency reverts"; // TODO
}

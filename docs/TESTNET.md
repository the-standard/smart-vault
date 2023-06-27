# Smart Vault Testing

You can now test our Smart Vaults on Sepolia, and Polygon Mumbai if you're feeling brave enough.

All the contracts you need there are verified on Etherscan/Polygonscan.

Here are some guides to getting set up and getting some test ETH/MATIC from a faucet:

- [Sepolia](https://www.alchemy.com/overviews/sepolia-testnet)
- [Mumbai](https://www.alchemy.com/overviews/mumbai-testnet)

## Opening a Smart Vault

Go to the [manager on Sepolia Etherscan](https://sepolia.etherscan.io/address/0x8e8fb106D22d0Eb7BB3D31BDB29964B5791c7C0E#writeProxyContract) or on Mumbai Polygonscan.

Connect your wallet to the block exporer.

Use the `mint` interface to create a new Smart Vault. Confirm this transaction with your connected wallet.

![Connect and mint](images/connect-and-mint.png)

In the Read as Proxy section, you'll find an interface called `vaults`. This contains a list of your Smart Vaults, and the current status of each vault.

The structure of this data is:

```
[
    {
        tokenId, // the ID of the NFT which represents your vault
        collateralRate, // the required colleteralisation percentage; 100000 = 100%
        feeRate, // the % fee you will be charged with each minting or burning of sEURO from your vault; 100000 = 100%
        status: {
            vaultAddress, // the address of your vault
            minted, // the amount of sEURO currently borrowed from your vault
            maxMintable, // the maximum total amount of sEURO that is borrowable from your vault, based on current collateral value
            collateralValue, // value of vault collateral in terms of sEURO
            collateral: [
                {
                    symbol, // the collateral assets symbol, converted to a 32-byte array
                    amount // amount of given collateral
                },
                ...
            ],
            liquidated, // boolean indicating whether vault has been liquidated
            version, // the version number of the vault
            vaultType // the stablecoin which is borrowable from the vault, converted to 32-byte array
        }
    },
    ...
]
```

This data is flattened into a tuple when accessed from block explorers, so will appear as followed:

![Vaults data](images/vaults-data.png)

## Borrowing sEURO

You can send test ETH/MATIC directly to your vault address to add some collateral. You can also send some [test tokens](#test-tokens) to your vault as collateral.

Once you have some collateral in your vault, you can go to the vault address to borrow some sEURO. Use the `mint` in the Smart Vault write interfaces:

```
_to (address) // the address of the user you want to receive the sEURO
_amount (uint259) // the amount you'd like to borrow (excl. minting fee)
                  // amount should be given in full 18 decimal form e.g. enter 100000000000000000000 to mint 100 sEURO
```

Please note you will not be able to borrow up the `maxMintable` amount, as a minting fee will be applied on top of this amount.

## Repaying sEURO

You can repay borrowed sEURO into your vault using `burn` in the Smart Vault write interface:

```
_amount (uint259) // the amount you'd like to repay into your vault (excl. burning fee)
                  // amount should be given in full 18 decimal form e.g. enter 100000000000000000000 to burn 100 sEURO
```

Please note, you will have to make an approval for the amount of sEURO that will be transferred as a fee. By default this will be 1% of the amount that you want to repay e.g. if you want to repay 100 sEURO, you will have to approve your vault address for 1 sEURO.

You will not be able to repay your full personal balance of sEURO, because a burning fee will be transferred in addition to the amount you repay.

Please also note that you cannot repay borrowed sEURO by simply transferring sEURO to your vault.

## Test Tokens

There are two mock tokens that you can use as vault collateral: [6 decimal sUSD](https://sepolia.etherscan.io/address/0x78D4BDd6771C87B66d66a5A89FE52d5F19D778c5#writeContract) and [18 decimal sUSD](https://sepolia.etherscan.io/address/0x4904AFBf65480Ca77Eb2DdfF39EdcEABE53D4373#writeContract)

Connect your wallet and use the `mint` interface to mint yourself 1000 of each token (limited to one transaction per 24 hours).

Send these tokens to your vault to use them as collateral. Both tokens are worth roughly 0.95 sEURO.

## Addresses

```
{
    "sepolia": {
        "SmartVaultManager": "0x8e8fb106D22d0Eb7BB3D31BDB29964B5791c7C0E",
        "SEuro": "0xf23F59316A2700D88F6F503B24aEE01118255645",
        "SUSD6": "0x78D4BDd6771C87B66d66a5A89FE52d5F19D778c5",
        "SUSD18": "0x4904AFBf65480Ca77Eb2DdfF39EdcEABE53D4373"
    },
    "mumbai": {
        "SmartVaultManager": "0xF05b859c70c58EF88A4418F808c8d197Bb4Caa79",
        "SEuro": "0xB0Bae7c7cDC0448eCF4bCbaACc25Ae8742Dc378f",
        "SUSD6": "0x0174347E772DA6358D7A5e57E47D6DCE105FA6c5",
        "SUSD18": "0xa42d9A1Be0cEBe19B37FE9Ce7aC881e62D97D6aC"
    }
}
```
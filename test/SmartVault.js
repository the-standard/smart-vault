const { ethers } = require('hardhat');
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE } = require('./common');

let VaultManager, Vault, user, otherUser, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ user, otherUser, protocol ] = await ethers.getSigners();
    clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    const seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, seuro.address,
      clEthUsd.address, clEurUsd.address, protocol.address
    );
    await VaultManager.connect(user).mint();
    const { vaultAddress } = (await VaultManager.connect(user).vaults())[0];
    Vault = await ethers.getContractAt('SmartVault', vaultAddress);
  });

  describe('collateral', async () => {
    it('only allows the vault owner to add collateral directly to smart vault', async () => {
      const value = ethers.utils.parseEther('1');
      let collateral = Vault.connect(otherUser).addCollateralETH({value});
      await expect(collateral).to.be.revertedWith('err-not-owner');

      collateral = Vault.connect(user).addCollateralETH({value});
      await expect(collateral).not.to.be.reverted;
    });
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const value = ethers.utils.parseEther('1');
      await Vault.connect(user).addCollateralETH({value});
      
      let mint = Vault.connect(otherUser).mint(user.address, value);
      await expect(mint).to.be.revertedWith('err-not-owner');

      mint = Vault.connect(user).mint(user.address, value);
      await expect(mint).not.to.be.reverted;
    });
  });
});
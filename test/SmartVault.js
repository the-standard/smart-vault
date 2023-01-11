const { ethers } = require('hardhat');
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf } = require('./common');

let VaultManager, Vault, user, otherUser, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ user, otherUser, protocol ] = await ethers.getSigners();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    const Seuro = await (await ethers.getContractFactory('ERC20Mock')).deploy('sEURO', 'SEURO', 18);
    const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address,
      ClEthUsd.address, ClEurUsd.address, protocol.address, TokenManager.address
    );
    await VaultManager.connect(user).mint();
    const { vaultAddress } = (await VaultManager.connect(user).vaults())[0];
    Vault = await ethers.getContractAt('SmartVault', vaultAddress);
  });

  describe('collateral', async () => {
    it('only allows the vault owner to add collateral directly to smart vault', async () => {
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});

      const { collateral } = await Vault.status();
      expect(getCollateralOf('ETH', collateral).amount).to.equal(value);
    });
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});
      
      let mint = Vault.connect(otherUser).mint(user.address, value);
      await expect(mint).to.be.revertedWith('err-not-owner');

      mint = Vault.connect(user).mint(user.address, value);
      await expect(mint).not.to.be.reverted;
    });
  });

  describe('ownership', async () => {
    it('will not allow setting of new owner if not manager', async () => {
      const ownerUpdate = Vault.connect(user).setOwner(otherUser.address);
      await expect(ownerUpdate).to.be.revertedWith('err-not-manager');
    });
  });
});
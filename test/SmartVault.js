const { ethers } = require('hardhat');
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf } = require('./common');

let VaultManager, Vault, TokenManager, admin, user, otherUser, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ admin, user, otherUser, protocol ] = await ethers.getSigners();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    const Seuro = await (await ethers.getContractFactory('ERC20Mock')).deploy('sEURO', 'SEURO', 18);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address
    );
    await VaultManager.connect(user).mint();
    const { vaultAddress } = (await VaultManager.connect(user).vaults())[0];
    Vault = await ethers.getContractAt('SmartVault', vaultAddress);
  });

  describe('collateral', async () => {
    it('accepts ETH as collateral', async () => {
    const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});

      const { collateral } = await Vault.status();
      expect(getCollateralOf('ETH', collateral).amount).to.equal(value);
    });

    it('accepts certain ERC20s as collateral', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(100000000);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
      // mint user 100 USDT
      const value = 100000000;
      await Tether.mint(user.address, value);

      await Tether.connect(user).transfer(Vault.address, value);

      const { collateral } = await Vault.status();
      expect(getCollateralOf('USDT', collateral).amount).to.equal(value);
    });
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});
      
      let mint = Vault.connect(otherUser).mint(user.address, value);
      await expect(mint).to.be.revertedWith('err-invalid-user');

      mint = Vault.connect(user).mint(user.address, value);
      await expect(mint).not.to.be.reverted;
    });
  });

  describe('ownership', async () => {
    it('will not allow setting of new owner if not manager', async () => {
      const ownerUpdate = Vault.connect(user).setOwner(otherUser.address);
      await expect(ownerUpdate).to.be.revertedWith('err-invalid-user');
    });
  });
});
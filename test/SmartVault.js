const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf } = require('./common');

let VaultManager, Vault, TokenManager, Seuro, admin, user, otherUser, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ admin, user, otherUser, protocol ] = await ethers.getSigners();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address
    );
    await Seuro.grantRole(await Seuro.DEFAULT_ADMIN_ROLE(), VaultManager.address);
    await VaultManager.connect(user).mint();
    const { vaultAddress } = (await VaultManager.connect(user).vaults())[0];
    Vault = await ethers.getContractAt('SmartVault', vaultAddress);
  });

  describe('collateral', async () => {
    it('accepts ETH as collateral', async () => {
    const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});

      const { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('ETH', collateral).amount).to.equal(value);
      const euroCollateral = value.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
      const maximumMint = euroCollateral.mul(100).div(120);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 6 decimal ERC20s as collateral', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
      // mint user 100 USDT
      const value = BigNumber.from(100000000);
      await Tether.mint(user.address, value);

      await Tether.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('USDT', collateral).amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const euroCollateral = value.mul(BigNumber.from(10).pow(12)).mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      const maximumMint = euroCollateral.mul(100).div(120);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 18 decimal ERC20s as collateral', async () => {
      const Dai = await (await ethers.getContractFactory('ERC20Mock')).deploy('Dai Stablecoin', 'DAI', 18);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Dai.address, ClUsdUsd.address);
      // mint user 100 DAI
      const value = ethers.utils.parseEther('100');
      await Dai.mint(user.address, value);

      await Dai.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('DAI', collateral).amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const euroCollateral = value.mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      const maximumMint = euroCollateral.mul(100).div(120);
      expect(maxMintable).to.equal(maximumMint);
    });
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      
      const mintedValue = ethers.utils.parseEther('100');
      let mint = Vault.connect(otherUser).mint(user.address, mintedValue);
      await expect(mint).to.be.revertedWith('err-invalid-user');

      mint = Vault.connect(user).mint(user.address, mintedValue);
      await expect(mint).not.to.be.reverted;
      const { minted } = await Vault.status();
      expect(minted).to.equal(mintedValue);

      const fee = mintedValue.div(100)
      expect(await Seuro.balanceOf(user.address)).to.equal(mintedValue.sub(fee));
    });
  });

  describe('burning', async () => {
    it('allows burning of sEURO if there is a minted amount, charges a fee', async () => {
      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});

      const burnedValue = ethers.utils.parseEther('50');
      let burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWith('err-insuff-minted');

      const mintedValue = ethers.utils.parseEther('100');
      await Vault.connect(user).mint(user.address, mintedValue);

      burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWith('ERC20: insufficient allowance');

      const mintingFee = mintedValue.div(100);
      const burningFee = burnedValue.div(100);

      // must allow transfer to protocol
      await Seuro.connect(user).approve(Vault.address, burningFee);
      burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).not.to.be.reverted;

      minted = (await Vault.status()).minted;
      expect(minted).to.equal(mintedValue.sub(burnedValue.sub(burningFee)));

      expect(await Seuro.balanceOf(user.address)).to.equal(minted.sub(mintingFee).sub(burningFee));
    });
  });

  describe('ownership', async () => {
    it('will not allow setting of new owner if not manager', async () => {
      const ownerUpdate = Vault.connect(user).setOwner(otherUser.address);
      await expect(ownerUpdate).to.be.revertedWith('err-invalid-user');
    });
  });
});
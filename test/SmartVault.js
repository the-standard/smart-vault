const { ethers, upgrades } = require('hardhat');
const { BigNumber } = ethers;
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf, ETH } = require('./common');
const { HUNDRED_PC } = require('./common');

let VaultManager, Vault, TokenManager, ClEthUsd, Seuro, admin, user, otherUser, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ admin, user, otherUser, protocol ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, ClEurUsd.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator')).deploy();
    VaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address, 
      protocol.address, TokenManager.address, SmartVaultDeployer.address,
      SmartVaultIndex.address, NFTMetadataGenerator.address
    ]);
    await SmartVaultIndex.setVaultManager(VaultManager.address);
    await Seuro.grantRole(await Seuro.DEFAULT_ADMIN_ROLE(), VaultManager.address);
    await VaultManager.connect(user).mint();
    const { status } = (await VaultManager.connect(user).vaults())[0];
    const { vaultAddress } = status;
    Vault = await ethers.getContractAt('SmartVault', vaultAddress);
  });

  describe('ownership', async () => {
    it('will not allow setting of new owner if not manager', async () => {
      const ownerUpdate = Vault.connect(user).setOwner(otherUser.address);
      await expect(ownerUpdate).to.be.revertedWith('err-invalid-user');
    });
  });

  describe('adding collateral', async () => {
    it('accepts native currency as collateral', async () => {
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      const collateralETH = getCollateralOf('ETH', collateral)
      expect(collateralETH.amount).to.equal(value);
      const euroCollateral = value.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
      expect(collateralETH.collateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 6 decimal ERC20s as collateral', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
      // mint user 100 USDT
      const value = BigNumber.from(100000000);
      await Tether.mint(user.address, value);

      await Tether.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      const collateralETH = getCollateralOf('USDT', collateral)
      expect(collateralETH.amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const euroCollateral = value.mul(BigNumber.from(10).pow(12)).mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      expect(collateralETH.collateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 18 decimal ERC20s as collateral', async () => {
      const Dai = await (await ethers.getContractFactory('ERC20Mock')).deploy('Dai Stablecoin', 'DAI', 18);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Dai.address, ClUsdUsd.address);
      // mint user 100 DAI
      const value = ethers.utils.parseEther('100');
      await Dai.mint(user.address, value);

      await Dai.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      expect(getCollateralOf('DAI', collateral).amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const euroCollateral = value.mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });
  });

  describe('removing collateral', async () => {
    it('allows removal of native currency if owner and it will not undercollateralise vault', async () => {
      const value = ethers.utils.parseEther('1');
      const half = value.div(2);
      await user.sendTransaction({to: Vault.address, value});

      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('ETH', collateral).amount).to.equal(value);

      let remove = Vault.connect(otherUser).removeCollateralNative(value, user.address);
      await expect(remove).to.be.revertedWith('err-invalid-user');

      remove = Vault.connect(user).removeCollateralNative(half, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'CollateralRemoved').withArgs(ETH, half, user.address);
      ({ collateral, maxMintable } = await Vault.status());
      expect(getCollateralOf('ETH', collateral).amount).to.equal(half);

      // mint max seuro
      const mintingFee = maxMintable.div(100);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateralNative(ethers.utils.parseEther('0.0001'), user.address);
      await expect(remove).to.be.revertedWith('err-under-coll');
    });

    it('allows removal of ERC20 if owner and it will not undercollateralise vault', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const USDTBytes = ethers.utils.formatBytes32String('USDT');
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);

      // 1000 USDT
      const value = 1000000000;
      const half = value / 2;
      await Tether.mint(Vault.address, value);

      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('USDT', collateral).amount).to.equal(value);

      let remove = Vault.connect(otherUser).removeCollateral(USDTBytes, value, user.address);
      await expect(remove).to.be.revertedWith('err-invalid-user');

      remove = Vault.connect(user).removeCollateral(USDTBytes, half, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'CollateralRemoved').withArgs(USDTBytes, half, user.address);
      ({ collateral, maxMintable } = await Vault.status());
      expect(getCollateralOf('USDT', collateral).amount).to.equal(half);

      // mint max seuro
      const mintingFee = maxMintable.div(100);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateral(ethers.utils.formatBytes32String('USDT'), 1000000, user.address);
      await expect(remove).to.be.revertedWith('err-under-coll');
    });

    it('allows removal of ERC20s that are or are not valid collateral, if not undercollateralising', async () => {
      const SUSD6 = await (await ethers.getContractFactory('ERC20Mock')).deploy('sUSD6', 'SUSD6', 6);
      const SUSD18 = await (await ethers.getContractFactory('ERC20Mock')).deploy('sUSD18', 'SUSD18', 18);
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
      await ClUsdUsd.setPrice(100000000)
      await TokenManager.addAcceptedToken(SUSD18.address, ClUsdUsd.address);
      const SUSD6value = 1000000000;
      const SUSD18value = ethers.utils.parseEther('1000');

      await expect(Vault.connect(user).removeAsset(SUSD6.address, SUSD6value, user.address)).to.be.revertedWith('ERC20: transfer amount exceeds balance');
      
      await SUSD6.mint(Vault.address, SUSD6value);
      await SUSD18.mint(Vault.address, SUSD18value);
      
      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('SUSD6', collateral)).to.be.undefined;
      expect(getCollateralOf('SUSD18', collateral).amount).to.equal(SUSD18value);
      
      await Vault.connect(user).mint(user.address, maxMintable.div(2));

      await expect(Vault.removeAsset(SUSD6.address, SUSD6value, user.address)).to.be.revertedWith('err-invalid-user');
      
      await Vault.connect(user).removeAsset(SUSD6.address, SUSD6value, user.address);
      expect(await SUSD6.balanceOf(Vault.address)).to.equal(0);
      expect(await SUSD6.balanceOf(user.address)).to.equal(SUSD6value);
      
      await expect(Vault.connect(user).removeAsset(SUSD18.address, SUSD18value, user.address)).to.be.revertedWith('err-under-coll');

      // partial removal, because some needed as collateral
      const part = SUSD18value.div(3);
      const remove = Vault.connect(user).removeAsset(SUSD18.address, part, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'AssetRemoved').withArgs(SUSD18.address, part, user.address);
      expect(await SUSD18.balanceOf(Vault.address)).to.equal(SUSD18value.sub(part));
      expect(await SUSD18.balanceOf(user.address)).to.equal(part);
    })
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const mintedValue = ethers.utils.parseEther('100');
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWith('err-under-coll');

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      
      let mint = Vault.connect(otherUser).mint(user.address, mintedValue);
      await expect(mint).to.be.revertedWith('err-invalid-user');

      mint = Vault.connect(user).mint(user.address, mintedValue);
      await expect(mint).not.to.be.reverted;
      const { minted } = await Vault.status();
      const fee = mintedValue.div(100)
      await expect(mint).emit(Vault, 'SEuroMinted').withArgs(user.address, mintedValue, fee);

      expect(minted).to.equal(mintedValue.add(fee));
      expect(await Seuro.balanceOf(user.address)).to.equal(mintedValue);
      expect(await Seuro.balanceOf(protocol.address)).to.equal(fee);
    });
  });

  describe('burning', async () => {
    it('allows burning of sEURO if there is a minted amount, charges a fee', async () => {
      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});

      const burnedValue = ethers.utils.parseEther('50');
      let burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWith('err-insuff-minted');

      // 100 to user
      // 1 to protocol
      // 101 minted in vault
      const mintedValue = ethers.utils.parseEther('100');
      await Vault.connect(user).mint(user.address, mintedValue);

      burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWith('ERC20: insufficient allowance');

      const mintingFee = mintedValue.div(100);
      const burningFee = burnedValue.div(100);

      // must allow transfer to protocol
      await Seuro.connect(user).approve(Vault.address, burningFee);
      // user pays back 50 to vault
      // .5 given to protocol
      // 51 minted in vault
      burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).not.to.be.reverted;
      await expect(burn).to.emit(Vault, 'SEuroBurned').withArgs(burnedValue, burningFee);

      minted = (await Vault.status()).minted;
      expect(minted).to.equal(mintedValue.add(mintingFee).sub(burnedValue));

      const fees = mintingFee.add(burningFee);
      expect(await Seuro.balanceOf(user.address)).to.equal(minted.sub(fees));
      expect(await Seuro.balanceOf(protocol.address)).to.equal(fees);
    });
  });

  describe('liquidation', async () => {
    it('indicates whether vault is undercollateralised in current state', async () => {
      expect(await Vault.undercollateralised()).to.equal(false);

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      expect(await Vault.undercollateralised()).to.equal(false);

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);
      expect(await Vault.undercollateralised()).to.equal(false);

      // eth / usd price drops to $1000
      await ClEthUsd.setPrice(100000000000);
      expect(await Vault.undercollateralised()).to.equal(true);
    });

    it('allows manager to liquidate vault, if undercollateralised', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);

      await expect(VaultManager.connect(protocol).liquidateVaults()).to.be.revertedWith('no-liquidatable-vaults');
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await expect(Vault.liquidate()).to.be.revertedWith('err-invalid-user');

      await expect(VaultManager.connect(protocol).liquidateVaults()).not.to.be.reverted;
      const { minted, maxMintable, totalCollateralValue, collateral, liquidated } = await Vault.status();
      expect(minted).to.equal(0);
      expect(maxMintable).to.equal(0);
      expect(totalCollateralValue).to.equal(0);
      collateral.forEach(asset => expect(asset.amount).to.equal(0));
      expect(liquidated).to.equal(true);
    });

    it('will not allow minting of seuro if liquidated', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await VaultManager.connect(protocol).liquidateVaults();
      const { liquidated } = await Vault.status();
      expect(liquidated).to.equal(true);

      await user.sendTransaction({to: Vault.address, value: ethValue.mul(2)});
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWith('err-liquidated');
    });
  });
});
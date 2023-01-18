const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC, getCollateralOf } = require('./common');

let VaultManager, TokenManager, Seuro, ClEthUsd, ClEurUsd, admin, user, protocol, otherUser;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, otherUser ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address
    );
    await Seuro.grantRole(await Seuro.DEFAULT_ADMIN_ROLE(), VaultManager.address);
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, no tokens minted, given collateral %', async () => {
      await VaultManager.connect(user).mint();
      
      const vaults = await VaultManager.connect(user).vaults();
      expect(vaults).to.be.length(1);
      const totalCollateral = vaults[0].status.collateral.reduce((a, b) => a.add(b.amount), BigNumber.from(0));
      expect(totalCollateral).to.equal(0);
      expect(vaults[0].status.minted).to.equal(0);
      expect(vaults[0].status.maxMintable).to.equal(0);
      expect(vaults[0].status.currentCollateralPercentage).to.equal(0);
      expect(vaults[0].collateralRate).to.equal(DEFAULT_COLLATERAL_RATE);
      expect(vaults[0].feeRate).to.equal(PROTOCOL_FEE_RATE);
    });
  });

  describe('TokenManager dependency', async () => {
    it('allows the owner to update the dependency, if not zero address', async () => {
      const NewTokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
      let update = VaultManager.connect(user).setTokenManager(NewTokenManager.address);
      await expect(update).to.be.revertedWith('Ownable: caller is not the owner');

      update = VaultManager.setTokenManager(NewTokenManager.address);
      await expect(update).not.to.be.reverted;
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);

      // not a new address
      update = VaultManager.setTokenManager(NewTokenManager.address);
      await expect(update).to.be.revertedWith('err-invalid-address');
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);

      // address zero
      update = VaultManager.setTokenManager(ethers.constants.AddressZero);
      await expect(update).to.be.revertedWith('err-invalid-address');
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);
    });
  });

  context('open vault', async () => {
    let tokenId;
    beforeEach(async () => {
      await VaultManager.connect(user).mint();
      await VaultManager.connect(otherUser).mint();
      ({ tokenId } = (await VaultManager.connect(user).vaults())[0]);
    });

    describe('addCollateralETH', async () => {
      it('accepts ETH as collateral, if sent by vault owner', async () => {
        const value = ethers.utils.parseEther('1');

        let collateral = VaultManager.connect(otherUser).addCollateralETH(tokenId, {value: value});
        await expect(collateral).to.be.revertedWith('err-not-owner');

        collateral = VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await expect(collateral).not.to.be.reverted;
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('ETH', status.collateral).amount;
        expect(ethCollateral).to.equal(value);
      });
  
      it('allows adding collateral multiple times', async () => {
        const value = ethers.utils.parseEther('1');
        // add 1 eth twice
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('ETH', status.collateral).amount;
        expect(ethCollateral).to.equal(value.mul(2));
      });

      it('facilitates adding ERC20s', async () => {
        const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
        const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(100000000);
        await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
        const USDTBytes = ethers.utils.formatBytes32String('USDT');
        
        const value = 100000000;
        await Tether.mint(user.address, value)

        let collateral = VaultManager.connect(otherUser).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).to.be.revertedWith('err-not-owner');

        collateral = VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).to.be.revertedWith('ERC20: insufficient allowance');

        await Tether.connect(user).approve(VaultManager.address, value);
        collateral = VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).not.to.be.reverted;
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('USDT', status.collateral).amount;
        expect(ethCollateral).to.equal(value);
      });
    });
  
    describe('minting', async () => {
      it('mints up to collateral percentage', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        const eurCollateralValue = collateralValue.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
        const maxMint = eurCollateralValue.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});

        let mint = VaultManager.connect(otherUser).mintSEuro(tokenId, user.address, maxMint);
        await expect(mint).to.be.revertedWith('err-not-owner');
  
        mint = VaultManager.connect(user).mintSEuro(tokenId, user.address, maxMint);
        await expect(mint).not.to.be.reverted;

        const { status } = (await VaultManager.connect(user).vaults())[0];
        expect(getCollateralOf('ETH', status.collateral).amount).to.equal(collateralValue);
        expect(status.minted).to.equal(maxMint);
        expect(status.maxMintable).to.equal(maxMint);
        expect(status.currentCollateralPercentage).to.equal(DEFAULT_COLLATERAL_RATE);
  
        // should overflow into under-collateralised
        mint = VaultManager.connect(user).mintSEuro(tokenId, user.address, 1);
        await expect(mint).to.be.revertedWith('err-under-coll');
      });
    });

    describe('burning', async () => {
      it('allows burning of sEURO through manager', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});

        const mintValue = ethers.utils.parseEther('100');
        await VaultManager.connect(user).mintSEuro(tokenId, user.address, mintValue);

        // user only has 99 because of minting fee
        const burnValue = ethers.utils.parseEther('99');

        // have to approve manager to control seuro to be burned
        let burn = VaultManager.connect(user).burnSEuro(tokenId, burnValue);
        await expect(burn).to.be.revertedWith('ERC20: insufficient allowance');

        // user has to have the seuro balance to burn
        await Seuro.connect(otherUser).approve(VaultManager.address, burnValue);
        burn = VaultManager.connect(otherUser).burnSEuro(tokenId, burnValue);
        await expect(burn).to.be.revertedWith('ERC20: transfer amount exceeds balance');

        await Seuro.connect(user).approve(VaultManager.address, burnValue);
        burn = VaultManager.connect(user).burnSEuro(tokenId, burnValue);
        await expect(burn).not.to.be.reverted;

        const { status } = (await VaultManager.connect(user).vaults())[0];
        // user was only able to pay back 98.01, due 1% minting fee and 1% burning fee
        expect(status.minted).to.equal(ethers.utils.parseEther('1.99'));
      });
    });
  
    describe('protocol fees', async () => {
      it('will send fee to protocol when minting', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});
  
        const mintAmount = ethers.utils.parseEther('100');
        const mintFee = mintAmount.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
  
        await VaultManager.connect(user).mintSEuro(tokenId, user.address, mintAmount);
  
        expect(await Seuro.balanceOf(user.address)).to.equal(mintAmount.sub(mintFee));
        expect(await Seuro.balanceOf(protocol.address)).to.equal(mintFee);
      });
    });

    describe('transfer of vault', async () => {
      it('will update the ownership data in SmartVaultManager', async () => {
        expect(await VaultManager.connect(user).vaults()).to.have.length(1);
        const otherUserVaults = await VaultManager.connect(otherUser).vaults();
        expect(otherUserVaults).to.have.length(1);
        const {tokenId, vaultAddress} = otherUserVaults[0];
        const Vault = await ethers.getContractAt('SmartVault', vaultAddress);
        expect(await Vault.owner()).to.equal(otherUser.address);

        await VaultManager.connect(otherUser).transferFrom(otherUser.address, user.address, tokenId);

        expect(await VaultManager.connect(user).vaults()).to.have.length(2);
        expect(await VaultManager.connect(otherUser).vaults()).to.have.length(0);
        expect(await Vault.owner()).to.equal(user.address);
      });
    });
  });

});
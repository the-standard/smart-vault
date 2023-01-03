const { ethers } = require('hardhat');
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC } = require('./common');

let vaultManager, seuro, admin, user, protocol, otherUser;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, otherUser ] = await ethers.getSigners();
    clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    vaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, seuro.address,
      clEthUsd.address, clEurUsd.address, protocol.address
    );
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, no tokens minted, given collateral %', async () => {
      await vaultManager.connect(user).mint();
      
      const vaults = await vaultManager.connect(user).vaults();
      expect(vaults).to.be.length(1);
      expect(vaults[0].collateral).to.equal(0);
      expect(vaults[0].minted).to.equal(0);
      expect(vaults[0].collateralRate).to.equal(DEFAULT_COLLATERAL_RATE);
      expect(vaults[0].feeRate).to.equal(PROTOCOL_FEE_RATE);
    });
  });

  context('open vault', async () => {
    let tokenId;
    beforeEach(async () => {
      await vaultManager.connect(user).mint();
      await vaultManager.connect(otherUser).mint();
      ({ tokenId } = (await vaultManager.connect(user).vaults())[0]);
    });

    describe('addCollateralETH', async () => {
      it('accepts ETH as collateral, if sent by vault owner', async () => {
        const value = ethers.utils.parseEther('1');

        let collateral = vaultManager.connect(otherUser).addCollateralETH(tokenId, {value: value});
        await expect(collateral).to.be.revertedWith('err-not-owner');

        collateral = vaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await expect(collateral).not.to.be.reverted;
        const vault = (await vaultManager.connect(user).vaults())[0];
        expect(vault.collateral).to.equal(value);
      });
  
      it('allows adding collateral multiple times', async () => {
        const value = ethers.utils.parseEther('1');
        // add 1 eth twice
        await vaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await vaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        const vault = (await vaultManager.connect(user).vaults())[0];
        expect(vault.collateral).to.equal(value.mul(2));
      });
    });
  
    describe('minting', async () => {
      it('mints up to collateral percentage', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        const eurCollateralValue = collateralValue.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
        const maxMint = eurCollateralValue.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
        await vaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});

        let mint = vaultManager.connect(otherUser).mintSEuro(tokenId, user.address, maxMint);
        await expect(mint).to.be.revertedWith('err-not-owner');
  
        mint = vaultManager.connect(user).mintSEuro(tokenId, user.address, maxMint);
        await expect(mint).not.to.be.reverted;
  
        // should overflow into under-collateralised
        mint = vaultManager.connect(user).mintSEuro(tokenId, user.address, 1);
        await expect(mint).to.be.revertedWith('err-under-coll');
      });
    });
  
    describe('protocol fees', async () => {
      it('will send fee to protocol when minting', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        await vaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});
  
        const mintAmount = ethers.utils.parseEther('100');
        const mintFee = mintAmount.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
  
        await vaultManager.connect(user).mintSEuro(tokenId, user.address, mintAmount);
  
        expect(await seuro.balanceOf(user.address)).to.equal(mintAmount.sub(mintFee));
        expect(await seuro.balanceOf(protocol.address)).to.equal(mintFee);
      });
    });

    describe('transfer of vault', async () => {
      it('will update the ownership data in SmartVaultManager', async () => {
        expect(await vaultManager.connect(user).vaults()).to.have.length(1);
        const otherUserVaults = await vaultManager.connect(otherUser).vaults();
        expect(otherUserVaults).to.have.length(1);

        await vaultManager.connect(otherUser).transferFrom(otherUser.address, user.address, otherUserVaults[0].tokenId);

        expect(await vaultManager.connect(user).vaults()).to.have.length(2);
        expect(await vaultManager.connect(otherUser).vaults()).to.have.length(0);
      });
    });
  });

});
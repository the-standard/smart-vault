const { expect } = require('chai');
const { ethers } = require('hardhat');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC } = require('./common');

let VaultManager, Seuro, admin, user, protocol, otherUser;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, otherUser ] = await ethers.getSigners();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy();
    Seuro = await (await ethers.getContractFactory('ERC20Mock')).deploy('sEURO', 'SEURO', 18);
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address,
      ClEthUsd.address, ClEurUsd.address, protocol.address, TokenManager.address
    );
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, no tokens minted, given collateral %', async () => {
      await VaultManager.connect(user).mint();
      
      const vaults = await VaultManager.connect(user).vaults();
      expect(vaults).to.be.length(1);
      expect(vaults[0].collateral).to.equal(0);
      expect(vaults[0].minted).to.equal(0);
      expect(vaults[0].collateralRate).to.equal(DEFAULT_COLLATERAL_RATE);
      expect(vaults[0].feeRate).to.equal(PROTOCOL_FEE_RATE);
    });
  });

  describe('TokenManager dependency', async () => {
    it('allows the owner to update the dependency, if not zero address', async () => {
      const NewTokenManager = await (await ethers.getContractFactory('TokenManager')).deploy();
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
        const vault = (await VaultManager.connect(user).vaults())[0];
        expect(vault.collateral).to.equal(value);
      });
  
      it('allows adding collateral multiple times', async () => {
        const value = ethers.utils.parseEther('1');
        // add 1 eth twice
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        const vault = (await VaultManager.connect(user).vaults())[0];
        expect(vault.collateral).to.equal(value.mul(2));
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

        const vault = (await VaultManager.connect(user).vaults())[0];
        expect(vault.collateral).to.equal(collateralValue);
        expect(vault.minted).to.equal(maxMint);
        expect(vault.maxMintable).to.equal(maxMint);
        expect(vault.currentCollateralPercentage).to.equal(DEFAULT_COLLATERAL_RATE);
  
        // should overflow into under-collateralised
        mint = VaultManager.connect(user).mintSEuro(tokenId, user.address, 1);
        await expect(mint).to.be.revertedWith('err-under-coll');
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
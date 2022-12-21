const { ethers } = require('hardhat');
const { expect } = require('chai');

const HUNDRED_PC = 100000;
const DEFAULT_COLLATERAL_RATE = 120000; // 120%
const DEFAULT_ETH_USD_PRICE = 125000000000; // $1250
const DEFAULT_EUR_USD_PRICE = 105000000; // $1.05
const PROTOCOL_FEE_RATE = 1000; // 1%
let vault, seuro, user, protocol;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ user, protocol ] = await ethers.getSigners();
    clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    vault = await (await ethers.getContractFactory('SmartVault')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, seuro.address, clEthUsd.address, clEurUsd.address, protocol.address
    );
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, no tokens minted, given collateral %', async () => {
      expect(await vault.collateral()).to.equal(0);
      expect(await vault.minted()).to.equal(0);
      expect(await vault.collateralRate()).to.equal(120000);
    });
  });

  describe('addCollateralETH', async () => {
    it('accepts ETH as collateral', async () => {
      const value = ethers.utils.parseEther('1');
      await vault.addCollateralETH({value: value});
      expect(await vault.collateral()).to.equal(value);
    });

    it('allows adding collateral multiple times', async () => {
      const value = ethers.utils.parseEther('1');
      // add 1 eth twice
      await vault.addCollateralETH({value: value});
      await vault.addCollateralETH({value: value});
      expect(await vault.collateral()).to.equal(value.mul(2));
    });
  });

  describe('minting', async () => {
    it('mints up to collateral percentage', async () => {
      const collateralValue = ethers.utils.parseEther('1');
      const eurCollateralValue = collateralValue.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
      const maxMint = eurCollateralValue.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      await vault.addCollateralETH({value: collateralValue});

      let mint = vault.mint(user.address, maxMint);
      await expect(mint).not.to.be.reverted;

      mint = vault.mint(user.address, maxMint);
      await expect(mint).to.be.revertedWith('err-under-coll');
    });
  });

  describe('protocol fees', async () => {
    it('will send fee to protocol when minting', async () => {
      const collateralValue = ethers.utils.parseEther('1');
      await vault.addCollateralETH({value: collateralValue});

      const mintAmount = ethers.utils.parseEther('100');
      const mintFee = mintAmount.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);

      await vault.mint(user.address, mintAmount);

      expect(await seuro.balanceOf(user.address)).to.equal(mintAmount.sub(mintFee));
      expect(await seuro.balanceOf(protocol.address)).to.equal(mintFee);
    });
  });
});
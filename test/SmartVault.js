const { ethers } = require('hardhat');
const { expect } = require('chai');

const DEFAULT_COLLATERAL_RATE = 120000;
const DEFAULT_ETH_USD_PRICE = 125000000000; // $1250
const DEFAULT_EUR_USD_PRICE = 105000000; // $1.05
let vault, owner;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ owner ] = await ethers.getSigners();
    clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    vault = await (await ethers.getContractFactory('SmartVault')).deploy(
      DEFAULT_COLLATERAL_RATE, seuro.address, clEthUsd.address, clEurUsd.address
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
      const maxMint = collateralValue.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
      await vault.addCollateralETH({value: collateralValue});

      let mint = vault.mint(owner.address, maxMint);
      await expect(mint).not.to.be.reverted;
      expect(await seuro.balanceOf(owner.address)).to.equal(maxMint);

      mint = vault.mint(owner.address, maxMint);
      await expect(mint).to.be.revertedWith('err-under-coll');
    });
  });
});
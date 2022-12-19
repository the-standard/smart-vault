const { ethers } = require('hardhat');
const { expect } = require('chai');

let vault;

describe('SmartVault', async () => {
  beforeEach(async () => {
    vault = await (await ethers.getContractFactory('SmartVault')).deploy();
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, and no tokens minted', async () => {
      expect(await vault.collateral()).to.equal(0);
      expect(await vault.minted()).to.equal(0);
    });
  });

  describe('addCollateralETH', async () => {
    it('accepts ETH as collateral', async () => {
      const value = ethers.utils.parseEther('1');
      await vault.addCollateralETH({value: value});
      expect(await vault.collateral()).to.equal(value);
    });
  });
});
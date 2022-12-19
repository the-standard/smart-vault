const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('SmartVault', async () => {
  describe('opening', async () => {
    it('opens a vault with no collateral deposited, and no tokens minted', async () => {
      const vault = await (await ethers.getContractFactory('SmartVault')).deploy();
      expect(await vault.collateral()).to.equal(0);
      expect(await vault.minted()).to.equal(0);
    });
  });
});
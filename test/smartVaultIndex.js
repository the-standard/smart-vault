const { expect } = require('chai');
const { ethers } = require("hardhat");
const { DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE } = require('./common');

describe('SmartVaultIndex', async () => {
  it('only allows manager address to update data', async () => {
    const [ admin, manager, vault, user ] = await ethers.getSigners();

    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    await SmartVaultIndex.setVaultManager(manager.address);

    await expect(SmartVaultIndex.connect(admin).addVaultAddress(1, vault.address)).to.be.revertedWith('err-unauthorised');
    await expect(SmartVaultIndex.connect(admin).transferTokenId(user.address, manager.address, 1)).to.be.revertedWith('err-unauthorised');

    await expect(SmartVaultIndex.connect(manager).addVaultAddress(1, vault.address)).not.to.be.reverted;
    await expect(SmartVaultIndex.connect(manager).transferTokenId(user.address, manager.address, 1)).not.to.be.reverted;
  });

  it('only allows owner to update manager address', async () => {
    const [ admin, manager, vault ] = await ethers.getSigners();

    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();

    await expect(SmartVaultIndex.connect(manager).setVaultManager(manager.address)).to.be.revertedWith('Ownable: caller is not the owner');

    await expect(SmartVaultIndex.connect(admin).setVaultManager(manager.address)).not.to.be.reverted;

    expect(await SmartVaultIndex.manager()).to.equal(manager.address);
  });
});
const { expect } = require('chai');
const { ethers } = require("hardhat");

describe.only('Contract Versioning', async () => {
  it('allows for v2 vaults with versioned vault manager', async () => {
    const [ admin, protocol, user ] = await ethers.getSigners();
    const SEuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEthUsd.setPrice(170000000000);
    const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEurUsd.setPrice(106000000);
    const VaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ClEurUsd.address);
    const VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      120000, 1000, SEuro.address, protocol.address, TokenManager.address, VaultDeployer.address
    );
    await SEuro.grantRole(await SEuro.DEFAULT_ADMIN_ROLE(), VaultManager.address);

    await VaultManager.connect(user).mint();
    const vaults = await VaultManager.connect(user).vaults();
    const v1Vault = vaults[0];
    expect(v1Vault.status.version).to.equal(1);
    expect(v1Vault.status.vaultType).to.equal(ethers.utils.formatBytes32String('SEURO'));
  });
});
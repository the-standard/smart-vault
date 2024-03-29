const { expect } = require('chai');
const { ethers, upgrades } = require("hardhat");
const { ETH, DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, getNFTMetadataContract } = require('./common');

describe('Contract Versioning', async () => {
  // TODO test using more than one currency vault
  // TODO test new liquidations (where collateral isn't sent)
  it('allows for v2 vaults with versioned vault manager', async () => {
    const [ admin, protocol, user ] = await ethers.getSigners();
    const EUROs = await (await ethers.getContractFactory('EUROsMock')).deploy();
    const ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    const TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('EUR / USD');
    await ClEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
    const VaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, ClEurUsd.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    const NFTMetadataGenerator = await (await getNFTMetadataContract()).deploy();
    const VaultManagerV1 = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
      DEFAULT_COLLATERAL_RATE, 1000, EUROs.address, protocol.address, admin.address,
      TokenManager.address, VaultDeployer.address, SmartVaultIndex.address, NFTMetadataGenerator.address
    ]);
    await EUROs.grantRole(await EUROs.DEFAULT_ADMIN_ROLE(), VaultManagerV1.address);
    await SmartVaultIndex.setVaultManager(VaultManagerV1.address);

    await VaultManagerV1.connect(user).mint();
    let [ v1Vault ] = await VaultManagerV1.connect(user).vaults();
    expect(v1Vault.status.version).to.equal(1);
    expect(v1Vault.status.vaultType).to.equal(ethers.utils.formatBytes32String('EUROs'));

    // version smart vault manager, to deploy v3 with different vaults
    const VaultDeployerV3 = await (await ethers.getContractFactory('TestSmartVaultDeployerV2')).deploy(ETH, ClEurUsd.address);
    const TokenManagerV2 = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);

    // try upgrading with non-owner
    let upgrade = upgrades.upgradeProxy(VaultManagerV1.address,
      await ethers.getContractFactory('TestSmartVaultManagerV2', user), {
        call: {fn: 'completeUpgrade', args: [VaultDeployerV3.address]}
      }
    );

    await expect(upgrade).to.be.revertedWith('Ownable: caller is not the owner');

    upgrade = upgrades.upgradeProxy(VaultManagerV1.address,
      await ethers.getContractFactory('TestSmartVaultManagerV2'), {
        call: {fn: 'completeUpgrade', args: [VaultDeployerV3.address]}
      }
    );

    await expect(upgrade).not.to.be.reverted;

    const VaultManagerV2 = await ethers.getContractAt('TestSmartVaultManagerV2', VaultManagerV1.address);
    expect(await VaultManagerV2.owner()).to.equal(admin.address);
    expect(await VaultManagerV2.ownerOf(1)).to.equal(user.address);

    await VaultManagerV2.connect(user).mint();

    const vaults = await VaultManagerV2.connect(user).vaults();
    v1Vault = vaults[0];
    const v2Vault = vaults[1];
    expect(v1Vault.status.version).to.equal(1);
    expect(v1Vault.status.vaultType).to.equal(ethers.utils.formatBytes32String('EUROs'));
    expect(v2Vault.status.version).to.equal(2);
    expect(v2Vault.status.vaultType).to.equal(ethers.utils.formatBytes32String('EUROs'));
  });
});
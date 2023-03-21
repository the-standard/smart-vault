const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC, getCollateralOf } = require('./common');

let VaultManager, TokenManager, Seuro, Tether, ClEthUsd, ClUsdUsd, admin, user, protocol, liquidator, otherUser;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, liquidator, otherUser ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
    ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy();
    await ClUsdUsd.setPrice(100000000);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ClEurUsd.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    VaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address, SmartVaultIndex.address
    ]);
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

  context('open vault', async () => {
    let tokenId, vaultAddress, otherTokenId, otherVaultAddress;
    beforeEach(async () => {
      await VaultManager.connect(user).mint();
      await VaultManager.connect(otherUser).mint();
      ({ tokenId, vaultAddress } = (await VaultManager.connect(user).vaults())[0]);
      const otherVault = (await VaultManager.connect(otherUser).vaults())[0];
      otherTokenId = otherVault.tokenId;
      otherVaultAddress = otherVault.vaultAddress;
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

    describe('liquidation', async () => {
      it('liquidates all undercollateralised vaults', async () => {
        const protocolETHBalance = await protocol.getBalance();
        const protocolUSDTBalance = await Tether.balanceOf(protocol.address);
        await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
        const tetherValue = 1000000000;
        const ethValue = ethers.utils.parseEther('1');
        await Tether.mint(vaultAddress, tetherValue);
        await user.sendTransaction({to: vaultAddress, value: ethValue});

        const { maxMintable } = (await VaultManager.connect(user).vaults())[0].status;
        const mintValue = maxMintable.mul(99).div(100);
        
        const vault = await ethers.getContractAt('SmartVault', vaultAddress);
        await vault.connect(user).mint(user.address, mintValue)

        // shouldn't liquidate any vaults, as both are sufficiently collateralised, should revert so no gas fees paid
        liquidate = VaultManager.connect(liquidator).liquidateVaults();
        await expect(liquidate).to.be.revertedWith('no-liquidatable-vaults');

        // drop price of eth to $1000, first vault becomes undercollateralised
        await ClEthUsd.setPrice(100000000000);

        // first user's vault should be liquidated
        liquidate = VaultManager.connect(liquidator).liquidateVaults();
        await expect(liquidate).not.to.be.reverted;
        const userVaults = await VaultManager.connect(user).vaults();
        const otherUserVaults = await VaultManager.connect(otherUser).vaults();
        expect(userVaults[0].status.liquidated).to.equal(true);
        expect(otherUserVaults[0].status.liquidated).to.equal(false);
        expect(userVaults[0].status.minted).to.equal(0);
        expect(userVaults[0].status.maxMintable).to.equal(0);
        expect(userVaults[0].status.currentCollateralPercentage).to.equal(0);
        userVaults[0].status.collateral.forEach(asset => {
          expect(asset.amount).to.equal(0);
        });
        expect(await Tether.balanceOf(protocol.address)).to.equal(protocolUSDTBalance.add(tetherValue));
        expect(await protocol.getBalance()).to.equal(protocolETHBalance.add(ethValue));
      });
    });
  });
});
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC, getCollateralOf, ETH } = require('./common');

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
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy(ETH, ClEurUsd.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    const NFTMetadataGenerator = await (await ethers.getContractFactory('NFTMetadataGenerator')).deploy();
    VaultManager = await upgrades.deployProxy(await ethers.getContractFactory('SmartVaultManager'), [
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address, SmartVaultIndex.address,
      NFTMetadataGenerator.address
    ]);
    await SmartVaultIndex.setVaultManager(VaultManager.address);
    await Seuro.grantRole(await Seuro.DEFAULT_ADMIN_ROLE(), VaultManager.address);
  });

  describe('mint and burn fee', async () => {
    it('allows owner to update mint and burn fee', async () => {
      expect(await VaultManager.mintFeeRate()).to.equal(PROTOCOL_FEE_RATE);
      expect(await VaultManager.burnFeeRate()).to.equal(PROTOCOL_FEE_RATE);

      const newMintFeeRate = 2000;
      const newBurnFeeRate = 3000;
      await expect(VaultManager.connect(user).setMintFeeRate(newMintFeeRate)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setBurnFeeRate(newBurnFeeRate)).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(VaultManager.setMintFeeRate(newMintFeeRate)).not.to.be.reverted;
      await expect(VaultManager.setBurnFeeRate(newBurnFeeRate)).not.to.be.reverted;

      expect(await VaultManager.mintFeeRate()).to.equal(newMintFeeRate);
      expect(await VaultManager.burnFeeRate()).to.equal(newBurnFeeRate);
    });
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
      expect(vaults[0].status.collateralValue).to.equal(0);
      expect(vaults[0].collateralRate).to.equal(DEFAULT_COLLATERAL_RATE);
      expect(vaults[0].mintFeeRate).to.equal(PROTOCOL_FEE_RATE);
      expect(vaults[0].burnFeeRate).to.equal(PROTOCOL_FEE_RATE);
    });
  });

  context('open vault', async () => {
    let tokenId, vaultAddress, otherTokenId, otherVaultAddress;
    beforeEach(async () => {
      await VaultManager.connect(user).mint();
      await VaultManager.connect(user).mint();
      await VaultManager.connect(otherUser).mint();
      ({ tokenId, vaultAddress } = (await VaultManager.connect(user).vaults())[0]);
      const otherVault = (await VaultManager.connect(otherUser).vaults())[0];
      otherTokenId = otherVault.tokenId;
      otherVaultAddress = otherVault.vaultAddress;
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
        expect(userVaults[0].status.collateralValue).to.equal(0);
        userVaults[0].status.collateral.forEach(asset => {
          expect(asset.amount).to.equal(0);
        });
        expect(await Tether.balanceOf(protocol.address)).to.equal(protocolUSDTBalance.add(tetherValue));
        expect(await protocol.getBalance()).to.equal(protocolETHBalance.add(ethValue));
      });
    });

    describe('transfer', async () => {
      it('should update all the ownership data properly', async () => {
        let userVaults = await VaultManager.connect(user).vaults();
        expect(userVaults).to.have.length(2);
        let otherUserVaults = await VaultManager.connect(otherUser).vaults();
        expect(otherUserVaults).to.have.length(1);
        const vault = await ethers.getContractAt('SmartVault', vaultAddress);
        expect(await vault.owner()).to.equal(user.address);

        await VaultManager.connect(user).transferFrom(user.address, otherUser.address, tokenId);

        expect(await VaultManager.ownerOf(tokenId)).to.equal(otherUser.address);

        userVaults = await VaultManager.connect(user).vaults();
        expect(userVaults).to.have.length(1);
        otherUserVaults = await VaultManager.connect(otherUser).vaults();
        expect(otherUserVaults).to.have.length(2);
        expect(otherUserVaults.map(v => v.tokenId.toString())).to.include(tokenId.toString());
        
        expect(await vault.owner()).to.equal(otherUser.address);
      });
    });

    describe('nft metadata', async () => {
      it('produces dynamic nft metadata', async () => {
        // json data url, should have "json" and "data" and "base64" in there
        expect(await VaultManager.tokenURI(1)).to.have.string('application/json');
        expect(await VaultManager.tokenURI(1)).to.have.string('data');
        expect(await VaultManager.tokenURI(1)).to.have.string('base64');
      });
    });
  });
});
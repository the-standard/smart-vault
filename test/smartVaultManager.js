const { expect } = require('chai');
const { ethers } = require('hardhat');
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { BigNumber } = ethers;
const { DEFAULT_ETH_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, ETH, getNFTMetadataContract, fullyUpgradedSmartVaultManager, WETH_ADDRESS, TEST_VAULT_LIMIT } = require('./common');

let VaultManager, TokenManager, USDs, Tether, ClEthUsd, ClUsdUsd, NFTMetadataGenerator,
MockSwapRouter, SmartVaultDeployer, admin, user, protocol, liquidator, otherUser, LiquidationPoolManager;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, liquidator, otherUser, LiquidationPoolManager ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
    await ClUsdUsd.setPrice(100000000);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    USDs = await (await ethers.getContractFactory('USDsMock')).deploy();
    Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const ClUSDCUSD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDC / USD');
    await ClUSDCUSD.setPrice(ethers.utils.parseUnits('1', 8));
    const PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, ClUSDCUSD.address);
    SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH, PriceCalculator.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    MockSwapRouter = await (await ethers.getContractFactory('MockSwapRouter')).deploy();
    NFTMetadataGenerator = await (await getNFTMetadataContract()).deploy();
    VaultManager = await fullyUpgradedSmartVaultManager(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, USDs.address, protocol.address,
      liquidator.address, TokenManager.address, SmartVaultDeployer.address,
      SmartVaultIndex.address, NFTMetadataGenerator.address, WETH_ADDRESS,
      MockSwapRouter.address, TEST_VAULT_LIMIT, ethers.constants.AddressZero
    );
    await SmartVaultIndex.setVaultManager(VaultManager.address);
    await USDs.grantRole(await USDs.DEFAULT_ADMIN_ROLE(), VaultManager.address);
    await USDs.grantRole(await USDs.BURNER_ROLE(), VaultManager.address);
  });

  describe('setting admin data', async () => {
    it('allows owner to admin data', async () => {
      expect(await VaultManager.mintFeeRate()).to.equal(PROTOCOL_FEE_RATE);
      expect(await VaultManager.burnFeeRate()).to.equal(PROTOCOL_FEE_RATE);
      expect(await VaultManager.swapFeeRate()).to.equal(PROTOCOL_FEE_RATE);
      expect(await VaultManager.nftMetadataGenerator()).to.equal(NFTMetadataGenerator.address);
      expect(await VaultManager.swapRouter()).to.equal(MockSwapRouter.address);
      expect(await VaultManager.weth()).to.equal(WETH_ADDRESS);
      expect(await VaultManager.smartVaultDeployer()).to.equal(SmartVaultDeployer.address);

      const newMintFeeRate = 2000;
      const newBurnFeeRate = 3000;
      const newSwapFeeRate = 4000;
      const newGenerator = await (await getNFTMetadataContract()).deploy();
      const newSwapRouter = await (await ethers.getContractFactory('MockSwapRouter')).deploy();
      const newWeth = await (await ethers.getContractFactory('ERC20Mock')).deploy('Wrapped Ether', 'WETH', 18);
      const deployerV2 = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH, ethers.constants.AddressZero);
      await expect(VaultManager.connect(user).setMintFeeRate(newMintFeeRate)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setBurnFeeRate(newBurnFeeRate)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setSwapFeeRate(newSwapFeeRate)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setNFTMetadataGenerator(newGenerator.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setSwapRouter(newSwapRouter.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setWethAddress(newWeth.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setSmartVaultDeployer(deployerV2.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setProtocolAddress(LiquidationPoolManager.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(VaultManager.connect(user).setLiquidatorAddress(LiquidationPoolManager.address)).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(VaultManager.setMintFeeRate(newMintFeeRate)).not.to.be.reverted;
      await expect(VaultManager.setBurnFeeRate(newBurnFeeRate)).not.to.be.reverted;
      await expect(VaultManager.setSwapFeeRate(newSwapFeeRate)).not.to.be.reverted;
      await expect(VaultManager.setNFTMetadataGenerator(newGenerator.address)).not.to.be.reverted;
      await expect(VaultManager.setSwapRouter(newSwapRouter.address)).not.to.be.reverted;
      await expect(VaultManager.setWethAddress(newWeth.address)).not.to.be.reverted;
      await expect(VaultManager.setSmartVaultDeployer(deployerV2.address)).not.to.be.reverted;
      await expect(VaultManager.setProtocolAddress(LiquidationPoolManager.address)).not.to.be.reverted;
      await expect(VaultManager.setLiquidatorAddress(LiquidationPoolManager.address)).not.to.be.reverted;

      expect(await VaultManager.mintFeeRate()).to.equal(newMintFeeRate);
      expect(await VaultManager.burnFeeRate()).to.equal(newBurnFeeRate);
      expect(await VaultManager.swapFeeRate()).to.equal(newSwapFeeRate);
      expect(await VaultManager.nftMetadataGenerator()).to.equal(newGenerator.address);
      expect(await VaultManager.swapRouter()).to.equal(newSwapRouter.address);
      expect(await VaultManager.weth()).to.equal(newWeth.address);
      expect(await VaultManager.smartVaultDeployer()).to.equal(deployerV2.address);
      expect(await VaultManager.protocol()).to.equal(LiquidationPoolManager.address);
      expect(await VaultManager.liquidator()).to.equal(LiquidationPoolManager.address);
    });
  });

  describe('opening', async () => {
    it('opens a vault with no collateral deposited, no tokens minted, given collateral %', async () => {
      const mint = VaultManager.connect(user).mint();
      await expect(mint).to.emit(VaultManager, 'VaultDeployed').withArgs(anyValue, user.address, USDs.address, 1);
      expect(await VaultManager.totalSupply()).to.equal(1);
      
      const vaultIDs = await VaultManager.vaultIDs(user.address);
      expect(vaultIDs).to.be.length(1);
      const vaultData = await VaultManager.vaultData(vaultIDs[0])
      const totalCollateral = vaultData.status.collateral.reduce((a, b) => a.add(b.amount), BigNumber.from(0));
      expect(totalCollateral).to.equal(0);
      expect(vaultData.status.minted).to.equal(0);
      expect(vaultData.status.maxMintable).to.equal(0);
      expect(vaultData.status.totalCollateralValue).to.equal(0);
      expect(vaultData.collateralRate).to.equal(DEFAULT_COLLATERAL_RATE);
      expect(vaultData.mintFeeRate).to.equal(PROTOCOL_FEE_RATE);
      expect(vaultData.burnFeeRate).to.equal(PROTOCOL_FEE_RATE);
    });

    it('does not let user exceed vault limit', async () => {
      for (let i = 0; i < TEST_VAULT_LIMIT; i++) {
        await VaultManager.connect(user).mint();
      }
      await expect(VaultManager.connect(user).mint()).to.be.revertedWith('err-vault-limit')
    });

    // it.only('supports a user having x amount of vaults', async () => {
    //   for (let i = 0; i < 1000; i++) {
    //     console.log(await VaultManager.connect(user).estimateGas.mint())
    //     await VaultManager.connect(user).mint();
    //     console.log(await VaultManager.vaultData(i + 1));
    //   }
    // });
  });

  context('open vault', async () => {
    let tokenId, vaultAddress, status;
    beforeEach(async () => {
      await VaultManager.connect(user).mint();
      await VaultManager.connect(user).mint();
      await VaultManager.connect(otherUser).mint();
      const [ vaultID ] = await VaultManager.connect(user).vaultIDs(user.address);
      ({ tokenId, status } = await VaultManager.vaultData(vaultID));
      ({ vaultAddress } = status);
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
        
        const [ vaultID ] = await VaultManager.vaultIDs(user.address);
        const { status } = await VaultManager.vaultData(vaultID);
        const mintValue = status.maxMintable.mul(99).div(100);
        
        const vault = await ethers.getContractAt('SmartVaultV4', vaultAddress);
        await vault.connect(user).mint(user.address, mintValue)

        let liquidate = VaultManager.connect(liquidator).liquidateVault(1);
        await expect(liquidate).to.be.revertedWith('ERC20: burn amount exceeds balance');

        await USDs.connect(admin).mint(liquidator.address, status.maxMintable);
        // shouldn't liquidate any vaults, as both are sufficiently collateralised, should revert so no gas fees paid
        liquidate = VaultManager.connect(liquidator).liquidateVault(1);
        await expect(liquidate).to.be.revertedWithCustomError(vault, 'NotUndercollateralised');
        liquidate = VaultManager.connect(liquidator).liquidateVault(2);
        await expect(liquidate).to.be.revertedWithCustomError(vault, 'NotUndercollateralised');

        // drop price of eth to $1000, first vault becomes undercollateralised
        await ClEthUsd.setPrice(100000000000);

        
        liquidate = VaultManager.connect(liquidator).liquidateVault(2);
        await expect(liquidate).to.be.revertedWithCustomError(vault, 'NotUndercollateralised');
        // first user's vault should be liquidated
        liquidate = VaultManager.connect(liquidator).liquidateVault(1);
        await expect(liquidate).not.to.be.reverted;
        await expect(liquidate).to.emit(VaultManager, 'VaultLiquidated').withArgs(vaultAddress);
        let [ tokenID ] = await VaultManager.vaultIDs(user.address);
        const userVault = await VaultManager.vaultData(tokenID);
        [ tokenID ] = await VaultManager.vaultIDs(otherUser.address);
        const otherUserVault = await VaultManager.vaultData(tokenID);
        expect(userVault.status.liquidated).to.equal(true);
        expect(otherUserVault.status.liquidated).to.equal(false);
        expect(userVault.status.minted).to.equal(0);
        expect(userVault.status.maxMintable).to.equal(0);
        expect(userVault.status.totalCollateralValue).to.equal(0);
        userVault.status.collateral.forEach(asset => {
          expect(asset.amount).to.equal(0);
        });
        expect(await Tether.balanceOf(liquidator.address)).to.equal(tetherValue);
        await expect(liquidate).to.changeEtherBalance(liquidator, ethValue);
      });
    });

    describe('transfer', async () => {
      it('should update all the ownership data properly', async () => {
        let userVaultIDs = await VaultManager.vaultIDs(user.address);
        expect(userVaultIDs).to.have.length(2);
        let otherUserVaultIDs = await VaultManager.vaultIDs(otherUser.address);
        expect(otherUserVaultIDs).to.have.length(1);
        const vault = await ethers.getContractAt('SmartVaultV4', vaultAddress);
        expect(await vault.owner()).to.equal(user.address);

        const transfer = VaultManager.connect(user).transferFrom(user.address, otherUser.address, tokenId);
        await expect(transfer).to.emit(VaultManager, 'VaultTransferred').withArgs(tokenId, user.address, otherUser.address);

        expect(await VaultManager.ownerOf(tokenId)).to.equal(otherUser.address);

        userVaultIDs = await VaultManager.vaultIDs(user.address);
        expect(userVaultIDs).to.have.length(1);
        otherUserVaultIDs = await VaultManager.vaultIDs(otherUser.address);
        expect(otherUserVaultIDs).to.have.length(2);
        expect(otherUserVaultIDs.map(id => id.toString())).to.include(tokenId.toString());
        
        expect(await vault.owner()).to.equal(otherUser.address);
      });
    });

    describe('nft metadata', async () => {
      it('produces dynamic nft metadata', async () => {
        // json data url, should have "json" and "data" and "base64" in there
        const metadataJSON = await VaultManager.tokenURI(1);
        expect(metadataJSON).to.have.string('application/json');
        expect(metadataJSON).to.have.string('data');
        expect(metadataJSON).to.have.string('base64');
      });
    });

    describe('vault version', async () => {
      it('deploys v4 vaults', async () => {
        const vault = await ethers.getContractAt('SmartVaultV4', vaultAddress);
        expect((await vault.status()).version).to.equal(4);
      });
    });
  });
});
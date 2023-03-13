const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, HUNDRED_PC, getCollateralOf } = require('./common');

let VaultManager, TokenManager, Seuro, Tether, ClEthUsd, ClEurUsd, ClUsdUsd, admin, user, protocol, liquidator, otherUser;

describe('SmartVaultManager', async () => {
  beforeEach(async () => {
    [ admin, user, protocol, liquidator, otherUser ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_ETH_USD_PRICE);
    ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(DEFAULT_EUR_USD_PRICE);
    ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy(100000000);
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
    Seuro = await (await ethers.getContractFactory('SEuroMock')).deploy();
    Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployer')).deploy();
    VaultManager = await (await ethers.getContractFactory('SmartVaultManager')).deploy(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, Seuro.address, protocol.address,
      TokenManager.address, SmartVaultDeployer.address
    );
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

  describe('TokenManager dependency', async () => {
    it('allows the owner to update the dependency, if not zero address', async () => {
      const NewTokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ClEthUsd.address, ClEurUsd.address);
      let update = VaultManager.connect(user).setTokenManager(NewTokenManager.address);
      await expect(update).to.be.revertedWith('Ownable: caller is not the owner');

      update = VaultManager.setTokenManager(NewTokenManager.address);
      await expect(update).not.to.be.reverted;
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);

      // not a new address
      update = VaultManager.setTokenManager(NewTokenManager.address);
      await expect(update).to.be.revertedWith('err-invalid-address');
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);

      // address zero
      update = VaultManager.setTokenManager(ethers.constants.AddressZero);
      await expect(update).to.be.revertedWith('err-invalid-address');
      expect(await VaultManager.tokenManager()).to.equal(NewTokenManager.address);
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

    describe('addCollateral', async () => {
      it('accepts ETH as collateral, if sent by vault owner', async () => {
        const value = ethers.utils.parseEther('1');

        let collateral = VaultManager.connect(otherUser).addCollateralETH(tokenId, {value: value});
        await expect(collateral).to.be.revertedWith('err-not-owner');

        collateral = VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await expect(collateral).not.to.be.reverted;
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('ETH', status.collateral).amount;
        expect(ethCollateral).to.equal(value);
      });
  
      it('allows adding collateral multiple times', async () => {
        const value = ethers.utils.parseEther('1');
        // add 1 eth twice
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('ETH', status.collateral).amount;
        expect(ethCollateral).to.equal(value.mul(2));
      });

      it('facilitates adding ERC20s', async () => {
        await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
        const USDTBytes = ethers.utils.formatBytes32String('USDT');
        
        const value = 100000000;
        await Tether.mint(user.address, value)

        let collateral = VaultManager.connect(otherUser).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).to.be.revertedWith('err-not-owner');

        collateral = VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).to.be.revertedWith('ERC20: insufficient allowance');

        await Tether.connect(user).approve(VaultManager.address, value);
        collateral = VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);
        await expect(collateral).not.to.be.reverted;
        const { status } = (await VaultManager.connect(user).vaults())[0];
        const ethCollateral = getCollateralOf('USDT', status.collateral).amount;
        expect(ethCollateral).to.equal(value);
      });
    });

    describe('removing collateral', async () => {
      it('allows removal of ETH if it will not under collateralise vault', async () => {
        const value = ethers.utils.parseEther('1');

        await VaultManager.connect(user).addCollateralETH(tokenId, {value: value});

        let { status } = (await VaultManager.connect(user).vaults())[0];
        expect(getCollateralOf('ETH', status.collateral).amount).to.equal(value);

        await VaultManager.connect(user).removeCollateralETH(tokenId, value);

        ({ status } = (await VaultManager.connect(user).vaults())[0]);
        expect(getCollateralOf('ETH', status.collateral).amount).to.equal(0);
      });

      it('allows removal of ERC20 if it will not under collateralise vault', async () => {
        await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
        const USDTBytes = ethers.utils.formatBytes32String('USDT');

        const value = 1000000000;
        await Tether.mint(user.address, value)
        await Tether.connect(user).approve(VaultManager.address, value);

        await VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);

        let { status } = (await VaultManager.connect(user).vaults())[0];
        expect(getCollateralOf('USDT', status.collateral).amount).to.equal(value);

        await VaultManager.connect(user).removeCollateral(tokenId, USDTBytes, value);
        
        ({ status } = (await VaultManager.connect(user).vaults())[0]);
        expect(getCollateralOf('USDT', status.collateral).amount).to.equal(0);
      });

      it('allows removal of assets by address when asset is (no longer) valid collateral', async () => {
        await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
        const USDTBytes = ethers.utils.formatBytes32String('USDT');

        const value = 1000000000;
        await Tether.mint(user.address, value)
        await Tether.connect(user).approve(VaultManager.address, value);

        await VaultManager.connect(user).addCollateral(tokenId, USDTBytes, value);

        let { status, vaultAddress } = (await VaultManager.connect(user).vaults())[0];
        expect(getCollateralOf('USDT', status.collateral).amount).to.equal(value);

        await TokenManager.removeAcceptedToken(USDTBytes);
        ({ status, vaultAddress } = (await VaultManager.connect(user).vaults())[0]);
        expect(getCollateralOf('USDT', status.collateral)).to.be.undefined;
        expect(await Tether.balanceOf(vaultAddress)).to.equal(value);

        await VaultManager.connect(user).removeAsset(tokenId, Tether.address, value);
        
        expect(await Tether.balanceOf(vaultAddress)).to.equal(0);
      });
    });
  
    describe('minting', async () => {
      it('mints up to collateral percentage', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        const eurCollateralValue = collateralValue.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
        const maxMint = eurCollateralValue.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});
  
        const mintingFee = maxMint.div(100);
        const mintValue = maxMint.sub(mintingFee);

        let mint = VaultManager.connect(otherUser).mintSEuro(tokenId, maxMint);
        await expect(mint).to.be.revertedWith('err-not-owner');

        mint = VaultManager.connect(user).mintSEuro(tokenId, mintValue);
        await expect(mint).not.to.be.reverted;

        const { status } = (await VaultManager.connect(user).vaults())[0];
        expect(getCollateralOf('ETH', status.collateral).amount).to.equal(collateralValue);
        expect(status.minted).to.equal(mintValue.add(mintValue.div(100)));
        expect(status.maxMintable).to.equal(maxMint);
        // should be roughly maxing out collateral rate, but give or take some decimals
        expect(status.currentCollateralPercentage.div(1000)).to.equal(DEFAULT_COLLATERAL_RATE.div(1000));
  
        // should overflow into under-collateralised
        mint = VaultManager.connect(user).mintSEuro(tokenId, ethers.utils.parseEther('1'));
        await expect(mint).to.be.revertedWith('err-under-coll');
      });
    });

    describe('burning', async () => {
      it('allows burning of sEURO through manager', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});

        const mintValue = ethers.utils.parseEther('100');
        const mintFee = mintValue.div(100);
        await VaultManager.connect(user).mintSEuro(tokenId, mintValue);

        const burnValue = ethers.utils.parseEther('90');
        const burnFee = burnValue.div(100);

        // have to approve manager to control seuro to be burned
        let burn = VaultManager.connect(user).burnSEuro(tokenId, burnValue);
        await expect(burn).to.be.revertedWith('ERC20: insufficient allowance');

        // user has to have the seuro balance to burn
        await Seuro.connect(otherUser).approve(VaultManager.address, burnValue.add(burnFee));
        burn = VaultManager.connect(otherUser).burnSEuro(tokenId, burnValue);
        await expect(burn).to.be.revertedWith('ERC20: transfer amount exceeds balance');

        await Seuro.connect(user).approve(VaultManager.address, burnValue.add(burnFee));
        burn = VaultManager.connect(user).burnSEuro(tokenId, burnValue);
        await expect(burn).not.to.be.reverted;

        const { status } = (await VaultManager.connect(user).vaults())[0];
        const mintedRemaining = mintValue.add(mintFee).sub(burnValue);
        expect(status.minted).to.equal(mintedRemaining);
      });
    });
  
    describe('protocol fees', async () => {
      it('will send fee to protocol when minting', async () => {
        const collateralValue = ethers.utils.parseEther('1');
        await VaultManager.connect(user).addCollateralETH(tokenId, {value: collateralValue});
  
        const mintAmount = ethers.utils.parseEther('100');
        const mintFee = mintAmount.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
  
        await VaultManager.connect(user).mintSEuro(tokenId, mintAmount);
  
        expect(await Seuro.balanceOf(user.address)).to.equal(mintAmount);
        expect(await Seuro.balanceOf(protocol.address)).to.equal(mintFee);
      });
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
      it('allows owner to set address of liquidator', async () => {
        let liquidator = VaultManager.setLiquidator(ethers.constants.AddressZero);
        await expect(liquidator).to.be.revertedWith('err-invalid-address');

        liquidator = VaultManager.connect(user).setLiquidator(protocol.address);
        await expect(liquidator).to.be.revertedWith('Ownable: caller is not the owner');

        liquidator = VaultManager.setLiquidator(protocol.address);
        await expect(liquidator).not.to.be.reverted;

        expect(await VaultManager.liquidator()).to.equal(protocol.address);
      });

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
        await VaultManager.connect(user).mintSEuro(tokenId, mintValue);

        // liquidations can only be run by liquidator
        await VaultManager.setLiquidator(liquidator.address);
        let liquidate = VaultManager.liquidateVaults();
        await expect(liquidate).to.be.revertedWith('err-invalid-user');

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
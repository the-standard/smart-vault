const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf, ETH, getNFTMetadataContract, fullyUpgradedSmartVaultManager, TEST_VAULT_LIMIT, DEFAULT_POOL_FEE } = require('./common');
const { HUNDRED_PC } = require('./common');

let VaultManager, Vault, TokenManager, ClEthUsd, USDs, USDC, MockSwapRouter, MockWeth, admin, user, otherUser, protocol, YieldManager, UniProxyMock, MockUSDsHypervisor;

const scaleDownChainlinkAccuracy = amount => {
  return amount.div(BigNumber.from(10).pow(8));
}

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ admin, user, otherUser, protocol ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    USDs = await (await ethers.getContractFactory('USDsMock')).deploy();
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    const ClUSDCUSD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDC / USD');
    await ClUSDCUSD.setPrice(ethers.utils.parseUnits('1', 8));
    const sequencerFeed = await (await ethers.getContractFactory('ChainlinkMock')).deploy('L2 Sequencer Uptime Status Feed');
    const PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, ClUSDCUSD.address, sequencerFeed.address);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH, PriceCalculator.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    const NFTMetadataGenerator = await (await getNFTMetadataContract()).deploy();
    MockSwapRouter = await (await ethers.getContractFactory('MockSwapRouter')).deploy();
    MockWeth = await (await ethers.getContractFactory('MockWETH')).deploy();
    USDC = await (await ethers.getContractFactory('ERC20Mock')).deploy('USD Coin', 'USDC', 6);
    UniProxyMock = await (await ethers.getContractFactory('UniProxyMock')).deploy();
    MockUSDsHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
      'USDs-USDC', 'USDs-USDC', USDs.address, USDC.address
    );
    YieldManager = await (await ethers.getContractFactory('SmartVaultYieldManager')).deploy(
      USDs.address, USDC.address, MockWeth.address, UniProxyMock.address, MockSwapRouter.address, MockUSDsHypervisor.address,
      MockSwapRouter.address
    );
    VaultManager = await fullyUpgradedSmartVaultManager(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, USDs.address, protocol.address, 
      protocol.address, TokenManager.address, SmartVaultDeployer.address,
      SmartVaultIndex.address, NFTMetadataGenerator.address, MockWeth.address,
      MockSwapRouter.address, TEST_VAULT_LIMIT, YieldManager.address
    );
    await YieldManager.setFeeData(PROTOCOL_FEE_RATE, VaultManager.address);
    await SmartVaultIndex.setVaultManager(VaultManager.address);
    await USDs.grantRole(await USDs.DEFAULT_ADMIN_ROLE(), VaultManager.address);
    await USDs.grantRole(await USDs.BURNER_ROLE(), VaultManager.address);
    await VaultManager.connect(user).mint();
    const [ vaultID ] = await VaultManager.vaultIDs(user.address);
    const { status } = await VaultManager.vaultData(vaultID);
    const { vaultAddress } = status;
    Vault = await ethers.getContractAt('SmartVaultV4', vaultAddress);
  });

  const defaultDeadline = async _ => {
    return (await ethers.provider.getBlock('latest')).timestamp + 60;
  }

  describe('ownership', async () => {
    it('will not allow setting of new owner if not manager', async () => {
      const ownerUpdate = Vault.connect(user).setOwner(otherUser.address);
      await expect(ownerUpdate).to.be.revertedWithCustomError(Vault, 'InvalidUser');
    });
  });

  describe('adding collateral', async () => {
    it('accepts native currency as collateral', async () => {
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      const collateralETH = getCollateralOf('ETH', collateral)
      expect(collateralETH.amount).to.equal(value);
      const usdCollateral = scaleDownChainlinkAccuracy(value.mul(DEFAULT_ETH_USD_PRICE));
      expect(collateralETH.collateralValue).to.equal(usdCollateral);
      expect(totalCollateralValue).to.equal(usdCollateral);
      expect(totalCollateralValue).to.equal(usdCollateral);
      const maximumMint = usdCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 6 decimal ERC20s as collateral', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);
      // mint user 100 USDT
      const value = BigNumber.from(100000000);
      await Tether.mint(user.address, value);

      await Tether.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      const collateralETH = getCollateralOf('USDT', collateral)
      expect(collateralETH.amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const usdCollateral = scaleDownChainlinkAccuracy(value.mul(BigNumber.from(10).pow(12)).mul(clUsdUsdPrice));
      expect(collateralETH.collateralValue).to.equal(usdCollateral);
      expect(totalCollateralValue).to.equal(usdCollateral);
      const maximumMint = usdCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts certain 18 decimal ERC20s as collateral', async () => {
      const Dai = await (await ethers.getContractFactory('ERC20Mock')).deploy('Dai Stablecoin', 'DAI', 18);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Dai.address, ClUsdUsd.address);
      // mint user 100 DAI
      const value = ethers.utils.parseEther('100');
      await Dai.mint(user.address, value);

      await Dai.connect(user).transfer(Vault.address, value);

      const { collateral, maxMintable, totalCollateralValue } = await Vault.status();
      expect(getCollateralOf('DAI', collateral).amount).to.equal(value);
      // scale up power of twelve because usdt is 6 dec
      const usdCollateral = scaleDownChainlinkAccuracy(value.mul(clUsdUsdPrice));
      expect(totalCollateralValue).to.equal(usdCollateral);
      const maximumMint = usdCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
    });

    it('accepts 30 dec erc20s as collateral', async () => {
      const usd30 = await (await ethers.getContractFactory('ERC20Mock')).deploy('30 dec usd', 'usd30', 30);
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
      await ClUsdUsd.setPrice(100000000);
      await TokenManager.addAcceptedToken(usd30.address, ClUsdUsd.address);

      const value = ethers.utils.parseUnits('1000', 30);
      await usd30.mint(Vault.address, value);
      
      const { totalCollateralValue } = await Vault.status();
      expect(totalCollateralValue).to.equal(ethers.utils.parseEther('1000'));
    });
  });

  describe('removing collateral', async () => {
    it('allows removal of native currency if owner and it will not undercollateralise vault', async () => {
      const value = ethers.utils.parseEther('1');
      const half = value.div(2);
      await user.sendTransaction({to: Vault.address, value});

      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('ETH', collateral).amount).to.equal(value);

      let remove = Vault.connect(otherUser).removeCollateralNative(value, user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      remove = Vault.connect(user).removeCollateralNative(half, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'CollateralRemoved').withArgs(ETH, half, user.address);
      ({ collateral, maxMintable } = await Vault.status());
      expect(getCollateralOf('ETH', collateral).amount).to.equal(half);

      // mint max usds
      const mintingFee = maxMintable.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateralNative(ethers.utils.parseEther('0.0001'), user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'Undercollateralised');
    });

    it('allows removal of ERC20 if owner and it will not undercollateralise vault', async () => {
      const Tether = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const USDTBytes = ethers.utils.formatBytes32String('USDT');
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Tether.address, ClUsdUsd.address);

      // 1000 USDT
      const value = 1000000000;
      const half = value / 2;
      await Tether.mint(Vault.address, value);

      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('USDT', collateral).amount).to.equal(value);

      let remove = Vault.connect(otherUser).removeCollateral(USDTBytes, value, user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      remove = Vault.connect(user).removeCollateral(USDTBytes, half, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'CollateralRemoved').withArgs(USDTBytes, half, user.address);
      ({ collateral, maxMintable } = await Vault.status());
      expect(getCollateralOf('USDT', collateral).amount).to.equal(half);

      // mint max usds
      const mintingFee = maxMintable.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateral(ethers.utils.formatBytes32String('USDT'), 1000000, user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'Undercollateralised');
    });

    it('allows removal of ERC20s that are or are not valid collateral, if not undercollateralising', async () => {
      const SUSD6 = await (await ethers.getContractFactory('ERC20Mock')).deploy('sUSD6', 'SUSD6', 6);
      const SUSD18 = await (await ethers.getContractFactory('ERC20Mock')).deploy('sUSD18', 'SUSD18', 18);
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USD / USD');
      await ClUsdUsd.setPrice(100000000)
      await TokenManager.addAcceptedToken(SUSD18.address, ClUsdUsd.address);
      const SUSD6value = 1000000000;
      const SUSD18value = ethers.utils.parseEther('1000');

      await expect(Vault.connect(user).removeAsset(SUSD6.address, SUSD6value, user.address)).to.be.revertedWith('ERC20: transfer amount exceeds balance');
      
      await SUSD6.mint(Vault.address, SUSD6value);
      await SUSD18.mint(Vault.address, SUSD18value);
      
      let { collateral, maxMintable } = await Vault.status();
      expect(getCollateralOf('SUSD6', collateral)).to.be.undefined;
      expect(getCollateralOf('SUSD18', collateral).amount).to.equal(SUSD18value);
      
      await Vault.connect(user).mint(user.address, maxMintable.div(2));

      await expect(Vault.removeAsset(SUSD6.address, SUSD6value, user.address)).to.be.revertedWithCustomError(Vault, 'InvalidUser');
      
      await Vault.connect(user).removeAsset(SUSD6.address, SUSD6value, user.address);
      expect(await SUSD6.balanceOf(Vault.address)).to.equal(0);
      expect(await SUSD6.balanceOf(user.address)).to.equal(SUSD6value);
      
      await expect(Vault.connect(user).removeAsset(SUSD18.address, SUSD18value, user.address)).to.be.revertedWithCustomError(Vault, 'Undercollateralised');

      // partial removal, because some needed as collateral
      const part = SUSD18value.div(3);
      const remove = Vault.connect(user).removeAsset(SUSD18.address, part, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'AssetRemoved').withArgs(SUSD18.address, part, user.address);
      expect(await SUSD18.balanceOf(Vault.address)).to.equal(SUSD18value.sub(part));
      expect(await SUSD18.balanceOf(user.address)).to.equal(part);

      // also allows removal of ETH with remove asset
      const value = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value});
      const removeETH = Vault.connect(user).removeAsset(ethers.constants.AddressZero, value, user.address);
      await expect(removeETH).not.to.be.reverted;
      await expect(removeETH).to.changeEtherBalance(user, value);
    })
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const mintedValue = ethers.utils.parseEther('100');
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWithCustomError(Vault, 'Undercollateralised');

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      
      let mint = Vault.connect(otherUser).mint(user.address, mintedValue);
      await expect(mint).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      mint = Vault.connect(user).mint(user.address, mintedValue);
      await expect(mint).not.to.be.reverted;
      const { minted } = await Vault.status();
      const fee = mintedValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC)
      await expect(mint).emit(Vault, 'USDsMinted').withArgs(user.address, mintedValue, fee);

      expect(minted).to.equal(mintedValue.add(fee));
      expect(await USDs.balanceOf(user.address)).to.equal(mintedValue);
      expect(await USDs.balanceOf(protocol.address)).to.equal(fee);
    });
  });

  describe('burning', async () => {
    it('allows burning of USDs if there is a minted amount, charges a fee', async () => {
      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});

      const burnedValue = ethers.utils.parseEther('50');
      let burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWithCustomError(Vault, 'Overrepay');

      // 100 to user
      // 1 to protocol
      // 101 minted in vault
      const mintedValue = ethers.utils.parseEther('100');
      await Vault.connect(user).mint(user.address, mintedValue);

      const mintingFee = mintedValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      const burningFee = burnedValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);

      // user pays back 50 to vault
      // .5 given to protocol
      // 51 minted in vault
      burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).not.to.be.reverted;
      await expect(burn).to.emit(Vault, 'USDsBurned').withArgs(burnedValue, burningFee);

      minted = (await Vault.status()).minted;
      expect(minted).to.equal(mintedValue.add(mintingFee).sub(burnedValue));

      const fees = mintingFee.add(burningFee);
      expect(await USDs.balanceOf(user.address)).to.equal(minted.sub(fees));
      expect(await USDs.balanceOf(protocol.address)).to.equal(fees);
    });
  });

  describe('liquidation', async () => {
    it('indicates whether vault is undercollateralised in current state', async () => {
      expect(await Vault.undercollateralised()).to.equal(false);

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      expect(await Vault.undercollateralised()).to.equal(false);

      const mintedValue = ethers.utils.parseEther('1000');
      await Vault.connect(user).mint(user.address, mintedValue);
      expect(await Vault.undercollateralised()).to.equal(false);

      // eth / usd price drops to $1000
      await ClEthUsd.setPrice(100000000000);
      expect(await Vault.undercollateralised()).to.equal(true);
    });

    it('allows manager to liquidate vault, if undercollateralised', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('1000');
      await Vault.connect(user).mint(user.address, mintedValue);

      await USDs.mint(protocol.address, (await Vault.status()).minted)
      await expect(VaultManager.connect(protocol).liquidateVault(1)).to.be.revertedWithCustomError(Vault, 'NotUndercollateralised');
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await expect(Vault.liquidate(protocol.address)).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      await expect(VaultManager.connect(protocol).liquidateVault(1)).not.to.be.reverted;
      const { minted, maxMintable, totalCollateralValue, collateral, liquidated } = await Vault.status();
      expect(minted).to.equal(0);
      expect(maxMintable).to.equal(0);
      expect(totalCollateralValue).to.equal(0);
      collateral.forEach(asset => expect(asset.amount).to.equal(0));
      expect(liquidated).to.equal(true);
    });

    it('will not allow minting of USDs if liquidated', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('1000');
      await Vault.connect(user).mint(user.address, mintedValue);
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await USDs.mint(protocol.address, (await Vault.status()).minted)
      await VaultManager.connect(protocol).liquidateVault(1);
      const { liquidated } = await Vault.status();
      expect(liquidated).to.equal(true);

      await user.sendTransaction({to: Vault.address, value: ethValue.mul(2)});
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWithCustomError(Vault, 'VaultLiquidated');
    });
  });

  describe('swaps', async () => {
    let Stablecoin;

    beforeEach(async () => {
      Stablecoin = await (await ethers.getContractFactory('ERC20Mock')).deploy('sUSD', 'sUSD', 6);
      const clUsdUsdPrice = 100000000;
      const ClUsdUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('sUSD / USD');
      await ClUsdUsd.setPrice(clUsdUsdPrice);
      await TokenManager.addAcceptedToken(Stablecoin.address, ClUsdUsd.address);
    });

    it('only allows owner to perform swap', async () => {
      const inToken = ethers.utils.formatBytes32String('ETH');
      const outToken = ethers.utils.formatBytes32String('sUSD');
      const swapValue = ethers.utils.parseEther('0.5');

      const now = (await ethers.provider.getBlock('latest')).timestamp;
      const swap = Vault.connect(admin).swap(inToken, outToken, swapValue, 0, DEFAULT_POOL_FEE, await defaultDeadline());

      await expect(swap).to.be.revertedWithCustomError(Vault, 'InvalidUser');
    });

    it('invokes swaprouter with value for eth swap, paying fees to protocol', async () => {
      const GIVEN_FEE = 500;
      // user vault has 1 ETH collateral
      await user.sendTransaction({to: Vault.address, value: ethers.utils.parseEther('1')});
      // user borrows 1200 USDs
      const borrowValue = ethers.utils.parseEther('1200');
      await Vault.connect(user).mint(user.address, borrowValue);
      const inToken = ethers.utils.formatBytes32String('ETH');
      const outToken = ethers.utils.formatBytes32String('sUSD');
      // user is swapping .5 ETH
      const swapValue = ethers.utils.parseEther('0.5');
      const swapFee = swapValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      
      const protocolBalance = await protocol.getBalance();
      
      // load up mock swap router
      await Stablecoin.mint(MockSwapRouter.address, 1_000_000_000_000);
      // rate of eth / usd is default rate, scaled down from 8 dec (chainlink) to 6 dec (stablecoin decimals)
      await MockSwapRouter.setRate(MockWeth.address, Stablecoin.address, DEFAULT_ETH_USD_PRICE / 100);

      const swapDeadline = await defaultDeadline();
      await Vault.connect(user).swap(inToken, outToken, swapValue, 0, GIVEN_FEE, swapDeadline);

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96
      } = await MockSwapRouter.receivedSwap();

      expect(tokenIn).to.equal(MockWeth.address);
      expect(tokenOut).to.equal(Stablecoin.address);
      expect(fee).to.equal(GIVEN_FEE);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(swapDeadline);
      expect(amountIn).to.equal(swapValue.sub(swapFee));
      expect(amountOutMinimum).to.equal(0); // something slightly wrong with the rounding calculation here
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(await MockWeth.balanceOf(protocol.address)).to.equal(swapFee);
    });

    it('amount out minimum is given by user if larger than minimum collateral value', async () => {
      // user vault has 1 ETH collateral
      await user.sendTransaction({to: Vault.address, value: ethers.utils.parseEther('1')});
      // user borrows 500 USDs
      const borrowValue = ethers.utils.parseEther('500');
      await Vault.connect(user).mint(user.address, borrowValue);
      const inToken = ethers.utils.formatBytes32String('ETH');
      const outToken = ethers.utils.formatBytes32String('sUSD');
      // user is swapping .5 ETH
      const swapValue = ethers.utils.parseEther('0.5');
      const swapFee = swapValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      const swapMinimum = 500_000_000; // user expect 500 sUSD out of swap
      // 1 ETH collateral = $1600
      // borrowed = 500 USDs
      // required collateral = 120% of 500 = $600
      // .5 swap = 50% of 1600 = $800
      // even if swap returned 0 assets, vault would remain above $600 required collateral value
      // minimum swap therefore 0
      const protocolBalance = await protocol.getBalance();
      
      // load up mock swap router
      await Stablecoin.mint(MockSwapRouter.address, 1_000_000_000_000);
      // rate of eth / usd is default rate, scaled down from 8 dec (chainlink) to 6 dec (stablecoin decimals)
      await MockSwapRouter.setRate(MockWeth.address, Stablecoin.address, DEFAULT_ETH_USD_PRICE / 100);

      const swapDeadline = await defaultDeadline();
      await Vault.connect(user).swap(inToken, outToken, swapValue, swapMinimum, DEFAULT_POOL_FEE, swapDeadline);

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96, txValue
      } = await MockSwapRouter.receivedSwap();

      expect(tokenIn).to.equal(MockWeth.address);
      expect(tokenOut).to.equal(Stablecoin.address);
      expect(fee).to.equal(DEFAULT_POOL_FEE);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(swapDeadline);
      expect(amountIn).to.equal(swapValue.sub(swapFee));
      expect(amountOutMinimum).to.equal(swapMinimum);
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(await MockWeth.balanceOf(protocol.address)).to.equal(swapFee);
    });

    it('invokes swaprouter after creating approval for erc20, paying fees to protocol, converting all weth back to eth', async () => {
      await Stablecoin.mint(Vault.address, ethers.utils.parseEther('100'));
      const inToken = ethers.utils.formatBytes32String('sUSD');
      const outToken = ethers.utils.formatBytes32String('ETH');
      const swapValue = ethers.utils.parseEther('50');
      const swapFee = swapValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      const actualSwap = swapValue.sub(swapFee);
      
      // load up mock weth
      await admin.sendTransaction({ to: MockWeth.address, value: ethers.utils.parseEther('1') });
      // load up mock swap router
      await MockWeth.mint(MockSwapRouter.address, ethers.utils.parseEther('1'));
      // rate of usd / eth is 1 / DEFAULT RATE * 10 ^ 20 (to scale from 6 dec to 18, and remove 8 dec scale down from chainlink price)
      await MockSwapRouter.setRate(Stablecoin.address, MockWeth.address, BigNumber.from(10).pow(20).div(DEFAULT_ETH_USD_PRICE));

      const swapDeadline = await defaultDeadline();
      await Vault.connect(user).swap(inToken, outToken, swapValue, 0, DEFAULT_POOL_FEE, swapDeadline);

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96, txValue
      } = await MockSwapRouter.receivedSwap();
      expect(tokenIn).to.equal(Stablecoin.address);
      expect(tokenOut).to.equal(MockWeth.address);
      expect(fee).to.equal(3000);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(swapDeadline);
      expect(amountIn).to.equal(actualSwap);
      expect(amountOutMinimum).to.equal(0);
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(await Stablecoin.balanceOf(protocol.address)).to.equal(swapFee);
    });
  });

  describe('yield', async () => {
    let WBTC, USDT, WBTCPerETH, MockWETHWBTCHypervisor;
    const FIFTY_PERCENT = HUNDRED_PC.div(2);

    beforeEach(async () => {
      WBTC = await (await ethers.getContractFactory('ERC20Mock')).deploy('Wrapped Bitcoin', 'WBTC', 8);
      USDT = await (await ethers.getContractFactory('ERC20Mock')).deploy('Tether', 'USDT', 6);
      const CL_WBTC_USD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
      await CL_WBTC_USD.setPrice(DEFAULT_ETH_USD_PRICE.mul(20));
      const CL_USDT_USD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDT / USD');
      await CL_USDT_USD.setPrice(BigNumber.from(10).pow(8));
      await TokenManager.addAcceptedToken(WBTC.address, CL_WBTC_USD.address);
      await TokenManager.addAcceptedToken(MockWeth.address, ClEthUsd.address);
      await TokenManager.addAcceptedToken(USDT.address, CL_USDT_USD.address);
      
      // fake gamma vault for WETH + WBTC
      MockWETHWBTCHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
        'WETH-WBTC', 'WETH-WBTC', MockWeth.address, WBTC.address
      );
      
      // data about how yield manager converts collateral to USDC, vault addresses etc
      await YieldManager.addHypervisorData(
        MockWeth.address, MockWETHWBTCHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [MockWeth.address, 3000, USDC.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, MockWeth.address])
      )
      await YieldManager.addHypervisorData(
        WBTC.address, MockWETHWBTCHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [WBTC.address, 3000, USDC.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, WBTC.address])
      )
      
      // ratio of USDs vault is 1:1, scaled up because USDs 18 dec and USDC 6 dec
      await UniProxyMock.setRatio(MockUSDsHypervisor.address, USDC.address, ethers.utils.parseUnits('1', 30));
      // ratio of weth / wbtc vault is 1:1 in value, or 20:1 in unscaled numbers (20*10**10:1) in scaled
      WBTCPerETH = ethers.utils.parseUnits('0.05',8)
      await UniProxyMock.setRatio(MockWETHWBTCHypervisor.address, MockWeth.address, WBTCPerETH);
      // ratio is inverse of above, 1:20 in unscaled numbers, or 1:20*10^8
      await UniProxyMock.setRatio(MockWETHWBTCHypervisor.address, WBTC.address, ethers.utils.parseUnits('20',28));
      
      // set fake rate for swap router: this is ETH / USDC: 1600 scaled down to 6 dec (or scaled down 2 dec from chainlink price)
      await MockSwapRouter.setRate(MockWeth.address, USDC.address, DEFAULT_ETH_USD_PRICE.div(100));
      await MockSwapRouter.setRate(USDC.address, MockWeth.address, ethers.utils.parseEther('1').div(DEFAULT_ETH_USD_PRICE).mul(ethers.utils.parseUnits('1', 20)));
      // set fake rate for USDC / USDs: 1:1, scaled up / down for 6 / 18 dec
      await MockSwapRouter.setRate(USDC.address, USDs.address, ethers.utils.parseUnits('1', 30));
      await MockSwapRouter.setRate(USDs.address, USDC.address, ethers.utils.parseUnits('1', 6));
      // set fake rate for ETH / WBTC: 0.05 WBTC scaled down to 8 dec
      await MockSwapRouter.setRate(MockWeth.address, WBTC.address, WBTCPerETH);
      // set fake rate for WBTC / USDs: ~32k, with scaling down 2 dec
      await MockSwapRouter.setRate(WBTC.address, USDC.address, DEFAULT_ETH_USD_PRICE.mul(20).mul(ethers.utils.parseUnits('1', 8)));
      // set fake rate for WBTC / ETH: 20 ETH scaled up by 10 dec
      await MockSwapRouter.setRate(WBTC.address, MockWeth.address, ethers.utils.parseUnits('20',28))
      
      // load up mock swap router
      await USDC.mint(MockSwapRouter.address, ethers.utils.parseEther('1000000'));
      await USDs.mint(MockSwapRouter.address, ethers.utils.parseEther('1000000'));
      await WBTC.mint(MockSwapRouter.address, ethers.utils.parseUnits('10', 8));
      await MockWeth.mint(MockSwapRouter.address, ethers.utils.parseEther('10'));
    }); 

    it('fetches empty yield list', async () => {
      expect(await Vault.yieldAssets()).to.be.empty;
    });

    it('puts all of given collateral asset into yield', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1')
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      
      let { collateral, totalCollateralValue } = await Vault.status();
      let preYieldCollateral = totalCollateralValue;
      expect(getCollateralOf('ETH', collateral).amount).to.equal(ethCollateral);

      // only vault owner can deposit collateral as yield
      let depositYield = Vault.connect(admin).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline());
      await expect(depositYield).to.be.revertedWithCustomError(Vault, 'InvalidUser');
      // 5% to stables pool is below minimum
      depositYield = Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(20), FIFTY_PERCENT, await defaultDeadline());
      await expect(depositYield).to.be.revertedWithCustomError(YieldManager, 'StablePoolPercentageError');
      // deadline has passed
      const now = Math.floor(new Date() / 1000);
      depositYield = Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, now - 60);
      await expect(depositYield).to.be.revertedWithCustomError(Vault, 'DeadlineExpired');
      depositYield = Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline());
      await expect(depositYield).not.to.be.reverted;
      await expect(depositYield).to.emit(YieldManager, 'Deposit').withArgs(Vault.address, MockWeth.address, ethCollateral, HUNDRED_PC.div(2));

      // USDT does not have hypervisor data set in yield manager
      const USDTBytes = ethers.utils.formatBytes32String('USDT');
      const USDTCollateral = ethers.utils.parseUnits('1000', 6);
      await USDT.mint(Vault.address, USDTCollateral);
      await expect(Vault.connect(user).depositYield(USDTBytes, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline())).to.be.revertedWithCustomError(YieldManager, 'HypervisorDataError');
      await Vault.connect(user).removeCollateral(USDTBytes, USDTCollateral, user.address);

      ({ collateral, totalCollateralValue } = await Vault.status());
      expect(getCollateralOf('ETH', collateral).amount).to.equal(0);
      // about 25% of collateral in USDs now, and therefore not included
      expect(totalCollateralValue).to.equal(preYieldCollateral.mul(3).div(4));

      const yieldAssets = await Vault.yieldAssets();
      expect(yieldAssets).to.have.length(2);
      expect([USDs.address, USDC.address]).to.include(yieldAssets[0].token0);
      expect([USDs.address, USDC.address]).to.include(yieldAssets[0].token1);
      expect(yieldAssets[0].amount0).to.be.closeTo(preYieldCollateral.div(4), 1);
      // scaled down because usdc is 6 dec
      expect(yieldAssets[0].amount1).to.equal(preYieldCollateral.div(4).div(ethers.utils.parseUnits('1', 12)));
      expect([WBTC.address, MockWeth.address]).to.include(yieldAssets[1].token0);
      expect([WBTC.address, MockWeth.address]).to.include(yieldAssets[1].token1);
      expect(yieldAssets[1].amount0).to.equal(ethCollateral.div(4), 1);
      // 0.1 ETH, quarter of which should be wbtc
      expect(yieldAssets[1].amount1).to.be.closeTo(WBTCPerETH / 40, 1);

      // add wbtc as collateral
      const wbtcCollateral = ethers.utils.parseUnits('0.005',8)
      await WBTC.mint(Vault.address, wbtcCollateral);

      ({ collateral, totalCollateralValue } = await Vault.status());
      expect(getCollateralOf('WBTC', collateral).amount).to.equal(wbtcCollateral);
      preYieldCollateral = totalCollateralValue;

      // deposit wbtc for yield, 25% to USDs pool
      depositYield = Vault.connect(user).depositYield(ethers.utils.formatBytes32String('WBTC'), HUNDRED_PC.div(4), FIFTY_PERCENT, await defaultDeadline());
      await expect(depositYield).to.emit(YieldManager, 'Deposit').withArgs(Vault.address, WBTC.address, wbtcCollateral, HUNDRED_PC.div(4)); // bit of accuracy issue
      ({ collateral, totalCollateralValue } = await Vault.status());
      expect(getCollateralOf('WBTC', collateral).amount).to.equal(0);
      // TODO assertions on the yield assets for wbtc deposit
    });

    it('removes hypervisor tokens in liquidation', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1')
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline());
      await Vault.connect(user).mint(user.address, ethers.utils.parseEther('90'));

      // tank eth price
      await ClEthUsd.setPrice(1);
      
      const vaultHypervisorBalance = await MockWETHWBTCHypervisor.balanceOf(Vault.address);

      await USDs.mint(otherUser.address, ethers.utils.parseEther('1000'));
      await VaultManager.connect(otherUser).liquidateVault(1);
      expect(await MockWETHWBTCHypervisor.balanceOf(otherUser.address)).to.equal(vaultHypervisorBalance);
      expect(await MockWETHWBTCHypervisor.balanceOf(Vault.address)).to.equal(0);
    });

    xit('can put 100% of yield deposit in stable pair', async () => {

    });

    it('allows deleting of yield data for a collateral type (and reverts)', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1')
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });

      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline())).not.to.be.reverted;

      await expect(YieldManager.connect(user).removeHypervisorData(MockWeth.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(YieldManager.connect(admin).removeHypervisorData(MockWeth.address)).not.to.be.reverted;

      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline())).to.be.revertedWithCustomError(YieldManager, 'HypervisorDataError');
    });

    it('withdraw yield deposits by vault', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });

      const preDepositCollateral = (await Vault.status()).totalCollateralValue

      // 25% yield to stable pool
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(4), FIFTY_PERCENT, await defaultDeadline());
      expect(await Vault.yieldAssets()).to.have.length(2);
      expect(getCollateralOf('ETH', (await Vault.status()).collateral).amount).to.equal(0);
      const [ USDsYield ] = await Vault.yieldAssets();

      const now = Math.floor(new Date() / 1000);
      let withdrawYield = Vault.connect(user).withdrawYield(USDsYield.hypervisor, ETH, FIFTY_PERCENT, now - 60);
      await expect(withdrawYield).to.be.revertedWithCustomError(Vault, 'DeadlineExpired');
      withdrawYield = Vault.connect(user).withdrawYield(USDsYield.hypervisor, ETH, FIFTY_PERCENT, await defaultDeadline());
      let protocolFee = ethCollateral.div(4).mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      await expect(withdrawYield).to.emit(YieldManager, 'Withdraw').withArgs(Vault.address, MockWeth.address, MockUSDsHypervisor.address, ethCollateral.div(4).sub(protocolFee)) // bit of an accuracy issue
      let { totalCollateralValue, collateral } = await Vault.status();
      // 25% of deposit in usd hypervisor, therefore 1/8 of collateral hidden in USDs deposit
      // 
      let expectedCollateral = preDepositCollateral.mul(99875).div(100000);
      expect(totalCollateralValue).to.be.closeTo(expectedCollateral, 2000);
      const yieldAssets = await Vault.yieldAssets();
      expect(yieldAssets).to.have.length(1);
      expect(yieldAssets[0].hypervisor).to.equal(MockWETHWBTCHypervisor.address);
      // should have withdrawn ~quarter of eth collateral, because that much was put in stable pool originally, minus protocol fee
      expect(getCollateralOf('ETH', collateral).amount).to.be.closeTo(ethCollateral.div(4).sub(protocolFee), 1);
      expect(await MockWeth.balanceOf(protocol.address)).to.be.closeTo(protocolFee, 1);
      await Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ethers.utils.formatBytes32String('WBTC'), FIFTY_PERCENT, await defaultDeadline());
      ({ totalCollateralValue, collateral } = await Vault.status());
      // ~99.5% of original collateral because all collateral withdrawn with .5% protocol fee rate
      expectedCollateral = preDepositCollateral.mul(HUNDRED_PC.sub(PROTOCOL_FEE_RATE)).div(HUNDRED_PC);
      expect(totalCollateralValue).to.be.closeTo(expectedCollateral, 2000);
      expect(await Vault.yieldAssets()).to.be.empty;
      // wbtc amount should be roughly equal to 0.075 ETH = 0.075
      const WBTCWithdrawal = WBTCPerETH.mul(ethCollateral.mul(3).div(4)).div(ethers.utils.parseEther('1'));
      protocolFee = WBTCWithdrawal.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      const expectedWBTC = WBTCWithdrawal.sub(protocolFee);
      expect(getCollateralOf('WBTC', collateral).amount).to.equal(expectedWBTC);
      expect(await WBTC.balanceOf(protocol.address)).to.equal(protocolFee);
    });

    it('reverts when collateral asset is not compatible with given asset on withdrawal', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), FIFTY_PERCENT, await defaultDeadline());

      // add usdc hypervisor data
      const MockUSDTWETHHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
        'USDT-WETH', 'USDT-WETH', USDT.address, MockWeth.address
      );
      // only allows own to set hypervisor data
      await expect(YieldManager.connect(user).addHypervisorData(
        USDT.address, MockUSDTWETHHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDT.address, 3000, USDC.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, USDT.address])
      )).to.be.revertedWith('Ownable: caller is not the owner');

      await expect(YieldManager.addHypervisorData(
        USDT.address, MockUSDTWETHHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDT.address, 3000, USDC.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, USDT.address])
      )).not.to.be.reverted;

      // weth / wbtc hypervisor cannot be withdrawn to USDT, even tho there is USDT hypervisor data
      await expect(Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ethers.utils.formatBytes32String('USDT'), FIFTY_PERCENT, await defaultDeadline()))
        .to.be.revertedWithCustomError(YieldManager, 'IncompatibleHypervisor');
    })

    it('reverts if collateral level falls below required level during deposit or withdrawal', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      // should be able to borrow up to $160
      // borrowing $120, 25% of collateral will be hidden as USDs
      await Vault.connect(user).mint(user.address, ethers.utils.parseEther('100'));

      // ETH / WBTC rate drops by 75%
      await MockSwapRouter.setRate(MockWeth.address, WBTC.address, WBTCPerETH.mul(3).div(4));
      
      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), 0, await defaultDeadline())).to.be.revertedWithCustomError(Vault, 'Undercollateralised');
      
      // reset ETH / WBTC to normal rate
      await MockSwapRouter.setRate(MockWeth.address, WBTC.address, WBTCPerETH);
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), 0, await defaultDeadline());
      
      // WBTC / ETH swap rate drops to 1 ETH per WBTC
      await MockSwapRouter.setRate(WBTC.address, MockWeth.address, ethers.utils.parseUnits('1',28))

      await expect(Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ETH, 0, await defaultDeadline())).to.be.revertedWithCustomError(Vault, 'Undercollateralised');
    });

    it('reverts if collateral level drops by given % during deposit or withdrawal', async () => {
      // required to maintain 90% during deposit + withdrawal
      const NINETY_PERCENT = HUNDRED_PC.mul(9).div(10);
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      
      // half of collateral going to usd hypervisor, therefore 25% of collateral going to be inactive
      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2), NINETY_PERCENT, await defaultDeadline())).to.be.revertedWithCustomError(Vault, 'Undercollateralised');

      // only put 10% in hypervisor, maintains collateral level enough
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(10), NINETY_PERCENT, await defaultDeadline());
      // WBTC / ETH swap price drops to 1:1, 90% threshold not maintained
      await MockSwapRouter.setRate(WBTC.address, MockWeth.address, ethers.utils.parseUnits('1',28))
      await expect(Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ETH, NINETY_PERCENT, await defaultDeadline())).to.be.revertedWithCustomError(Vault, 'Undercollateralised');
    });

    it('reverts if ratio is not reached within limited swap iterations', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });

      // 0.001 wbtc returned for 1 eth in swapping, ratio cannot be reached
      await MockSwapRouter.setRate(MockWeth.address, WBTC.address, 100000)

      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(4), FIFTY_PERCENT, await defaultDeadline())).to.be.revertedWithCustomError(YieldManager, 'RatioError');
    });

    it('only allows owner to set fee data', async() => {
      await expect(YieldManager.connect(user).setFeeData(1000, ethers.constants.AddressZero)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(YieldManager.connect(admin).setFeeData(1000, ethers.constants.AddressZero)).not.to.be.reverted;
    });
  });
});
const { ethers } = require('hardhat');
const { BigNumber } = ethers;
const { expect } = require('chai');
const { DEFAULT_ETH_USD_PRICE, DEFAULT_EUR_USD_PRICE, DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, getCollateralOf, ETH, getNFTMetadataContract, fullyUpgradedSmartVaultManager, TEST_VAULT_LIMIT } = require('./common');
const { HUNDRED_PC } = require('./common');

let VaultManager, Vault, TokenManager, ClEthUsd, EUROs, EURA, MockSwapRouter, MockWeth, admin, user, otherUser, protocol, YieldManager, UniProxyMock, MockEUROsHypervisor;

describe('SmartVault', async () => {
  beforeEach(async () => {
    [ admin, user, otherUser, protocol ] = await ethers.getSigners();
    ClEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await ClEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);
    const ClEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('EUR / USD');
    await ClEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
    EUROs = await (await ethers.getContractFactory('EUROsMock')).deploy();
    TokenManager = await (await ethers.getContractFactory('TokenManager')).deploy(ETH, ClEthUsd.address);
    const SmartVaultDeployer = await (await ethers.getContractFactory('SmartVaultDeployerV4')).deploy(ETH, ClEurUsd.address);
    const SmartVaultIndex = await (await ethers.getContractFactory('SmartVaultIndex')).deploy();
    const NFTMetadataGenerator = await (await getNFTMetadataContract()).deploy();
    MockSwapRouter = await (await ethers.getContractFactory('MockSwapRouter')).deploy();
    MockWeth = await (await ethers.getContractFactory('MockWETH')).deploy();
    EURA = await (await ethers.getContractFactory('ERC20Mock')).deploy('EURA', 'EURA', 18);
    UniProxyMock = await (await ethers.getContractFactory('UniProxyMock')).deploy();
    MockEUROsHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
      'EUROs-EURA', 'EUROs-EURA', EUROs.address, EURA.address
    );
    YieldManager = await (await ethers.getContractFactory('SmartVaultYieldManager')).deploy(
      EUROs.address, EURA.address, MockWeth.address, UniProxyMock.address, MockSwapRouter.address, MockEUROsHypervisor.address,
      MockSwapRouter.address
    );
    VaultManager = await fullyUpgradedSmartVaultManager(
      DEFAULT_COLLATERAL_RATE, PROTOCOL_FEE_RATE, EUROs.address, protocol.address, 
      protocol.address, TokenManager.address, SmartVaultDeployer.address,
      SmartVaultIndex.address, NFTMetadataGenerator.address, MockWeth.address,
      MockSwapRouter.address, TEST_VAULT_LIMIT, YieldManager.address
    );
    await SmartVaultIndex.setVaultManager(VaultManager.address);
    await EUROs.grantRole(await EUROs.DEFAULT_ADMIN_ROLE(), VaultManager.address);
    await EUROs.grantRole(await EUROs.MINTER_ROLE(), admin.address);
    await VaultManager.connect(user).mint();
    const [ vaultID ] = await VaultManager.vaultIDs(user.address);
    const { status } = await VaultManager.vaultData(vaultID);
    const { vaultAddress } = status;
    Vault = await ethers.getContractAt('SmartVaultV4', vaultAddress);
  });

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
      const euroCollateral = value.mul(DEFAULT_ETH_USD_PRICE).div(DEFAULT_EUR_USD_PRICE);
      expect(collateralETH.collateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
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
      const euroCollateral = value.mul(BigNumber.from(10).pow(12)).mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      expect(collateralETH.collateralValue).to.equal(euroCollateral);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
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
      const euroCollateral = value.mul(clUsdUsdPrice).div(DEFAULT_EUR_USD_PRICE);
      expect(totalCollateralValue).to.equal(euroCollateral);
      const maximumMint = euroCollateral.mul(HUNDRED_PC).div(DEFAULT_COLLATERAL_RATE);
      expect(maxMintable).to.equal(maximumMint);
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

      // mint max euros
      const mintingFee = maxMintable.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateralNative(ethers.utils.parseEther('0.0001'), user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'InvalidRequest');
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

      // mint max euros
      const mintingFee = maxMintable.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      await Vault.connect(user).mint(user.address, maxMintable.sub(mintingFee));

      // cannot remove any eth
      remove = Vault.connect(user).removeCollateral(ethers.utils.formatBytes32String('USDT'), 1000000, user.address);
      await expect(remove).to.be.revertedWithCustomError(Vault, 'InvalidRequest');
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
      
      await expect(Vault.connect(user).removeAsset(SUSD18.address, SUSD18value, user.address)).to.be.revertedWithCustomError(Vault, 'InvalidRequest');

      // partial removal, because some needed as collateral
      const part = SUSD18value.div(3);
      const remove = Vault.connect(user).removeAsset(SUSD18.address, part, user.address);
      await expect(remove).not.to.be.reverted;
      await expect(remove).to.emit(Vault, 'AssetRemoved').withArgs(SUSD18.address, part, user.address);
      expect(await SUSD18.balanceOf(Vault.address)).to.equal(SUSD18value.sub(part));
      expect(await SUSD18.balanceOf(user.address)).to.equal(part);
    })
  });

  describe('minting', async () => {
    it('only allows the vault owner to mint from smart vault directly', async () => {
      const mintedValue = ethers.utils.parseEther('100');
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWithCustomError(Vault, 'InvalidRequest');

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      
      let mint = Vault.connect(otherUser).mint(user.address, mintedValue);
      await expect(mint).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      mint = Vault.connect(user).mint(user.address, mintedValue);
      await expect(mint).not.to.be.reverted;
      const { minted } = await Vault.status();
      const fee = mintedValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC)
      await expect(mint).emit(Vault, 'EUROsMinted').withArgs(user.address, mintedValue, fee);

      expect(minted).to.equal(mintedValue.add(fee));
      expect(await EUROs.balanceOf(user.address)).to.equal(mintedValue);
      expect(await EUROs.balanceOf(protocol.address)).to.equal(fee);
    });
  });

  describe('burning', async () => {
    it('allows burning of EUROs if there is a minted amount, charges a fee', async () => {
      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});

      const burnedValue = ethers.utils.parseEther('50');
      let burn = Vault.connect(user).burn(burnedValue);
      await expect(burn).to.be.revertedWithCustomError(Vault, 'InvalidRequest');

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
      await expect(burn).to.emit(Vault, 'EUROsBurned').withArgs(burnedValue, burningFee);

      minted = (await Vault.status()).minted;
      expect(minted).to.equal(mintedValue.add(mintingFee).sub(burnedValue));

      const fees = mintingFee.add(burningFee);
      expect(await EUROs.balanceOf(user.address)).to.equal(minted.sub(fees));
      expect(await EUROs.balanceOf(protocol.address)).to.equal(fees);
    });
  });

  describe('liquidation', async () => {
    it('indicates whether vault is undercollateralised in current state', async () => {
      expect(await Vault.undercollateralised()).to.equal(false);

      const collateral = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: collateral});
      expect(await Vault.undercollateralised()).to.equal(false);

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);
      expect(await Vault.undercollateralised()).to.equal(false);

      // eth / usd price drops to $1000
      await ClEthUsd.setPrice(100000000000);
      expect(await Vault.undercollateralised()).to.equal(true);
    });

    it('allows manager to liquidate vault, if undercollateralised', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);

      await expect(VaultManager.connect(protocol).liquidateVault(1)).to.be.revertedWith('vault-not-undercollateralised')
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await expect(Vault.liquidate()).to.be.revertedWithCustomError(Vault, 'InvalidUser');

      await expect(VaultManager.connect(protocol).liquidateVault(1)).not.to.be.reverted;
      const { minted, maxMintable, totalCollateralValue, collateral, liquidated } = await Vault.status();
      expect(minted).to.equal(0);
      expect(maxMintable).to.equal(0);
      expect(totalCollateralValue).to.equal(0);
      collateral.forEach(asset => expect(asset.amount).to.equal(0));
      expect(liquidated).to.equal(true);
    });

    it('will not allow minting of EUROs if liquidated', async () => {
      const ethValue = ethers.utils.parseEther('1');
      await user.sendTransaction({to: Vault.address, value: ethValue});

      const mintedValue = ethers.utils.parseEther('900');
      await Vault.connect(user).mint(user.address, mintedValue);
      
      // drop price, now vault is liquidatable
      await ClEthUsd.setPrice(100000000000);

      await VaultManager.connect(protocol).liquidateVault(1);
      const { liquidated } = await Vault.status();
      expect(liquidated).to.equal(true);

      await user.sendTransaction({to: Vault.address, value: ethValue.mul(2)});
      await expect(Vault.connect(user).mint(user.address, mintedValue)).to.be.revertedWithCustomError(Vault, 'InvalidRequest');
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
      const swap = Vault.connect(admin).swap(inToken, outToken, swapValue, 0);

      await expect(swap).to.be.revertedWithCustomError(Vault, 'InvalidUser');
    });

    it('invokes swaprouter with value for eth swap, paying fees to protocol', async () => {
      // user vault has 1 ETH collateral
      await user.sendTransaction({to: Vault.address, value: ethers.utils.parseEther('1')});
      // user borrows 1200 EUROs
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

      const swap = await Vault.connect(user).swap(inToken, outToken, swapValue, 0);
      const ts = (await ethers.provider.getBlock(swap.blockNumber)).timestamp;

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96, txValue
      } = await MockSwapRouter.receivedSwap();

      expect(tokenIn).to.equal(MockWeth.address);
      expect(tokenOut).to.equal(Stablecoin.address);
      expect(fee).to.equal(3000);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(ts + 60);
      expect(amountIn).to.equal(swapValue.sub(swapFee));
      expect(amountOutMinimum).to.be.greaterThan(738030000); // something slightly wrong with the rounding calculation here
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(txValue).to.equal(swapValue.sub(swapFee));
      expect(await protocol.getBalance()).to.equal(protocolBalance.add(swapFee));
    });

    it('amount out minimum is given by user if larger than minimum collateral value', async () => {
      // user vault has 1 ETH collateral
      await user.sendTransaction({to: Vault.address, value: ethers.utils.parseEther('1')});
      // user borrows 500 EUROs
      const borrowValue = ethers.utils.parseEther('500');
      await Vault.connect(user).mint(user.address, borrowValue);
      const inToken = ethers.utils.formatBytes32String('ETH');
      const outToken = ethers.utils.formatBytes32String('sUSD');
      // user is swapping .5 ETH
      const swapValue = ethers.utils.parseEther('0.5');
      const swapFee = swapValue.mul(PROTOCOL_FEE_RATE).div(HUNDRED_PC);
      const swapMinimum = 500_000_000; // user expect 500 sUSD out of swap
      // 1 ETH collateral = $1600 / 1.06 (eur / usd) = €1509.43
      // borrowed = 500 EUROs
      // required collateral = 120% of 500 = €600
      // .5 swap = 50% of 1509.43 = €754.72
      // even if swap returned 0 assets, vault would remain above €600 required collateral value
      // minimum swap therefore 0
      const protocolBalance = await protocol.getBalance();
      
      // load up mock swap router
      await Stablecoin.mint(MockSwapRouter.address, 1_000_000_000_000);
      // rate of eth / usd is default rate, scaled down from 8 dec (chainlink) to 6 dec (stablecoin decimals)
      await MockSwapRouter.setRate(MockWeth.address, Stablecoin.address, DEFAULT_ETH_USD_PRICE / 100);

      const swap = await Vault.connect(user).swap(inToken, outToken, swapValue, swapMinimum);
      const ts = (await ethers.provider.getBlock(swap.blockNumber)).timestamp;

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96, txValue
      } = await MockSwapRouter.receivedSwap();

      expect(tokenIn).to.equal(MockWeth.address);
      expect(tokenOut).to.equal(Stablecoin.address);
      expect(fee).to.equal(3000);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(ts + 60);
      expect(amountIn).to.equal(swapValue.sub(swapFee));
      expect(amountOutMinimum).to.equal(swapMinimum);
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(txValue).to.equal(swapValue.sub(swapFee));
      expect(await protocol.getBalance()).to.equal(protocolBalance.add(swapFee));
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

      const swap = await Vault.connect(user).swap(inToken, outToken, swapValue, 0);
      const ts = (await ethers.provider.getBlock(swap.blockNumber)).timestamp;

      const {
        tokenIn, tokenOut, fee, recipient, deadline, amountIn, amountOutMinimum,
        sqrtPriceLimitX96, txValue
      } = await MockSwapRouter.receivedSwap();
      expect(tokenIn).to.equal(Stablecoin.address);
      expect(tokenOut).to.equal(MockWeth.address);
      expect(fee).to.equal(3000);
      expect(recipient).to.equal(Vault.address);
      expect(deadline).to.equal(ts + 60);
      expect(amountIn).to.equal(actualSwap);
      expect(amountOutMinimum).to.equal(0);
      expect(sqrtPriceLimitX96).to.equal(0);
      expect(txValue).to.equal(0);
      expect(await Stablecoin.balanceOf(protocol.address)).to.equal(swapFee);
    });
  });

  describe.only('yield', async () => {
    let WBTC, USDC, WBTCPerETH, MockWETHWBTCHypervisor;

    beforeEach(async () => {
      WBTC = await (await ethers.getContractFactory('ERC20Mock')).deploy('Wrapped Bitcoin', 'WBTC', 8);
      USDC = await (await ethers.getContractFactory('ERC20Mock')).deploy('USD Coin', 'USDC', 6);
      const CL_WBTC_USD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
      await CL_WBTC_USD.setPrice(DEFAULT_ETH_USD_PRICE.mul(20));
      const CL_USDC_USD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDC / USD');
      await CL_USDC_USD.setPrice(BigNumber.from(10).pow(8));
      await TokenManager.addAcceptedToken(WBTC.address, CL_WBTC_USD.address);
      await TokenManager.addAcceptedToken(MockWeth.address, ClEthUsd.address);
      await TokenManager.addAcceptedToken(USDC.address, CL_USDC_USD.address);
      
      // fake gamma vault for WETH + WBTC
      MockWETHWBTCHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
        'WETH-WBTC', 'WETH-WBTC', MockWeth.address, WBTC.address
      );

      // data about how yield manager converts collateral to EURA, vault addresses etc
      await YieldManager.addHypervisorData(
        MockWeth.address, MockWETHWBTCHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [MockWeth.address, 3000, EURA.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [EURA.address, 3000, MockWeth.address])
      )
      await YieldManager.addHypervisorData(
        WBTC.address, MockWETHWBTCHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [WBTC.address, 3000, EURA.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [EURA.address, 3000, WBTC.address])
      )

      // ratio of euros vault is 1:1
      await UniProxyMock.setRatio(MockEUROsHypervisor.address, EURA.address, ethers.utils.parseEther('1'));
      // ratio of weth / wbtc vault is 1:1 in value, or 20:1 in unscaled numbers (20*10**10:1) in scaled
      WBTCPerETH = ethers.utils.parseUnits('0.05',8)
      await UniProxyMock.setRatio(MockWETHWBTCHypervisor.address, MockWeth.address, WBTCPerETH);
      // ratio is inverse of above, 1:20 in unscaled numbers, or 1:20*10^8
      await UniProxyMock.setRatio(MockWETHWBTCHypervisor.address, WBTC.address, ethers.utils.parseUnits('20',28));

      // set fake rate for swap router: this is ETH / EUROs: ~1500
      await MockSwapRouter.setRate(MockWeth.address, EURA.address, DEFAULT_ETH_USD_PRICE.mul(ethers.utils.parseEther('1')).div(DEFAULT_EUR_USD_PRICE));
      await MockSwapRouter.setRate(EURA.address, MockWeth.address, ethers.utils.parseEther('1').mul(DEFAULT_EUR_USD_PRICE).div(DEFAULT_ETH_USD_PRICE));
      // set fake rate for EURA / EURO: 1:1
      await MockSwapRouter.setRate(EURA.address, EUROs.address, ethers.utils.parseEther('1'));
      await MockSwapRouter.setRate(EUROs.address, EURA.address, ethers.utils.parseEther('1'));
      // set fake rate for ETH / WBTC: 0.05 WBTC scaled down to 8 dec
      await MockSwapRouter.setRate(MockWeth.address, WBTC.address, WBTCPerETH);
      // set fake rate for WBTC / EUROS: ~30.1k, with scaling up by 10 dec
      await MockSwapRouter.setRate(WBTC.address, EURA.address, DEFAULT_ETH_USD_PRICE.mul(20).mul(ethers.utils.parseUnits('1', 28)).div(DEFAULT_EUR_USD_PRICE))
      // set fake rate for WBTC / ETH: 20 ETH scaled up by 10 dec
      await MockSwapRouter.setRate(WBTC.address, MockWeth.address, ethers.utils.parseUnits('20',28))

      // load up mock swap router
      await EURA.mint(MockSwapRouter.address, ethers.utils.parseEther('1000000'));
      await EUROs.mint(MockSwapRouter.address, ethers.utils.parseEther('1000000'));
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
      await expect(Vault.connect(admin).depositYield(ETH, HUNDRED_PC.div(2))).to.be.revertedWithCustomError(Vault, 'InvalidUser');
      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2))).not.to.be.reverted;

      // USDC does not have hypervisor data set in yield manager
      const USDCBytes = ethers.utils.formatBytes32String('USDC');
      const USDCCollateral = ethers.utils.parseUnits('1000', 6);
      await USDC.mint(Vault.address, USDCCollateral);
      await expect(Vault.connect(user).depositYield(USDCBytes, HUNDRED_PC.div(2))).to.be.revertedWithCustomError(Vault, 'InvalidRequest');
      await Vault.connect(user).removeCollateral(USDCBytes, USDCCollateral, user.address);

      ({ collateral, totalCollateralValue } = await Vault.status());
      expect(getCollateralOf('ETH', collateral).amount).to.equal(0);
      // allow a delta of 2 wei in pre and post yield collateral, due to dividing etc
      expect(totalCollateralValue).to.be.closeTo(preYieldCollateral, 2);

      const yieldAssets = await Vault.yieldAssets();
      expect(yieldAssets).to.have.length(2);
      expect([EUROs.address, EURA.address]).to.include(yieldAssets[0].token0);
      expect([EUROs.address, EURA.address]).to.include(yieldAssets[0].token1);
      expect(yieldAssets[0].amount0).to.be.closeTo(preYieldCollateral.div(4), 1);
      expect(yieldAssets[0].amount1).to.be.closeTo(preYieldCollateral.div(4), 1);
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

      // deposit wbtc for yield, 25% to euros pool
      await Vault.connect(user).depositYield(ethers.utils.formatBytes32String('WBTC'), HUNDRED_PC.div(4));
      ({ collateral, totalCollateralValue } = await Vault.status());
      expect(getCollateralOf('WBTC', collateral).amount).to.equal(0);
      expect(totalCollateralValue).to.be.closeTo(preYieldCollateral, 1);
      // TODO assertions on the yield assets for wbtc deposit
    });

    it('allows deleting of yield data for a collateral type (and reverts)', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1')
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });

      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2))).not.to.be.reverted;

      await expect(YieldManager.connect(user).removeHypervisorData(MockWeth.address)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(YieldManager.connect(admin).removeHypervisorData(MockWeth.address)).not.to.be.reverted;

      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      await expect(Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2))).to.be.revertedWithCustomError(YieldManager, 'InvalidRequest');
    });

    it('withdraw yield deposits by vault', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });

      // 25% yield to stable pool
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(4));
      expect(await Vault.yieldAssets()).to.have.length(2);
      const status = await Vault.status();
      const preWithdrawCollateralValue = status.totalCollateralValue;
      expect(getCollateralOf('ETH', status.collateral).amount).to.equal(0);
      const [ EUROsYield ] = await Vault.yieldAssets();

      await Vault.connect(user).withdrawYield(EUROsYield.hypervisor, ETH);
      let { totalCollateralValue, collateral } = await Vault.status();
      // fake rate from swap router causing a slight accuracy area
      expect(totalCollateralValue).to.be.closeTo(preWithdrawCollateralValue, 2000);
      const yieldAssets = await Vault.yieldAssets();
      expect(yieldAssets).to.have.length(1);
      expect(yieldAssets[0].hypervisor).to.equal(MockWETHWBTCHypervisor.address);
      // should have withdrawn ~quarter of eth collateral, because that much was put in stable pool originally
      expect(getCollateralOf('ETH', collateral).amount).to.be.closeTo(ethCollateral.div(4), 1);

      await Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ethers.utils.formatBytes32String('WBTC'));
      ({ totalCollateralValue, collateral } = await Vault.status());
      // fake rate from swap router causing a slight accuracy area
      expect(totalCollateralValue).to.be.closeTo(preWithdrawCollateralValue, 2000);
      expect(await Vault.yieldAssets()).to.be.empty;
      // wbtc amount should be roughly equal to 0.075 ETH = 0.075
      const expectedWBTC = WBTCPerETH.mul(ethCollateral.mul(3).div(4)).div(ethers.utils.parseEther('1'));
      expect(getCollateralOf('WBTC', collateral).amount).to.equal(expectedWBTC);
    });

    it('reverts when collateral asset is not compatible with given asset on withdrawal', async () => {
      const ethCollateral = ethers.utils.parseEther('0.1');
      await user.sendTransaction({ to: Vault.address, value: ethCollateral });
      await Vault.connect(user).depositYield(ETH, HUNDRED_PC.div(2));

      // add usdc hypervisor data
      const MockUSDCWETHHypervisor = await (await ethers.getContractFactory('HypervisorMock')).deploy(
        'USDC-WETH', 'USDC-WETH', USDC.address, MockWeth.address
      );
      await YieldManager.addHypervisorData(
        USDC.address, MockUSDCWETHHypervisor.address, 500,
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [USDC.address, 3000, EURA.address]),
        new ethers.utils.AbiCoder().encode(['address', 'uint24', 'address'], [EURA.address, 3000, USDC.address])
      )

      // weth / wbtc hypervisor cannot be withdrawn to usdc, even tho there is usdc hypervisor data
      await expect(Vault.connect(user).withdrawYield(MockWETHWBTCHypervisor.address, ethers.utils.formatBytes32String('USDC')))
        .to.be.revertedWithCustomError(YieldManager, 'InvalidRequest');
    })

    xit('reverts if collateral level falls below required level');
  });
});
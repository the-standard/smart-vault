const { expect } = require('chai');
const { ethers } = require("hardhat");
const { ETH, DEFAULT_ETH_USD_PRICE } = require('./common');

let PriceCalculator, Ethereum, WBTC;

describe('PriceCalculator', async () => {
  let clEthUsd, sequencerFeed;

  beforeEach(async () => {
    clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await clEthUsd.setPrice(DEFAULT_ETH_USD_PRICE)
    const clWBTCUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
    await clWBTCUsd.setPrice(DEFAULT_ETH_USD_PRICE.mul(20))
    const clUSDCUSD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDC / USD');
    await clUSDCUSD.setPrice(ethers.utils.parseUnits('1', 8));
    sequencerFeed = await (await ethers.getContractFactory('ChainlinkMock')).deploy('L2 Sequencer Uptime Status Feed');
    PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, clUSDCUSD.address, sequencerFeed.address);
    Ethereum = {
      symbol: ETH,
      addr: ethers.constants.AddressZero,
      dec: 18,
      clAddr: clEthUsd.address,
      clDec: 8
    };
    const wbtc = await (await ethers.getContractFactory('ERC20Mock')).deploy('Wrapped Bitcoin', 'WBTC', 8);
    WBTC = {
      symbol: ethers.utils.formatBytes32String('WBTC'),
      addr: wbtc.address,
      dec: 8,
      clAddr: clWBTCUsd.address,
      clDec: 8
    };
  });

  describe('tokenToUSD', async () => {
    it('returns the value of token in USD based on the latest chainlink price', async () => {
      // latest ETH price is $1600
      const etherValue = ethers.utils.parseEther('1');
      let expectedUsdValue = ethers.utils.parseEther('1600');
      let usdValue = await PriceCalculator.tokenToUSD(Ethereum, etherValue);
      expect(usdValue).to.equal(expectedUsdValue);

      // latest WBTC price is $32000
      const wbtcValue = ethers.utils.parseUnits('0.5', 8);
      expectedUsdValue = ethers.utils.parseEther('16000');
      usdValue = await PriceCalculator.tokenToUSD(WBTC, wbtcValue);
      expect(usdValue).to.equal(expectedUsdValue);
    });

    it('reverts if price data is invalid', async () => {
      const etherValue = ethers.utils.parseEther('1');

      // set round ID to 0
      await clEthUsd.setRoundID(0);
      await expect(PriceCalculator.tokenToUSD(Ethereum, etherValue)).to.be.revertedWithCustomError(PriceCalculator, 'InvalidRoundId');
      // reset to valid round ID
      await clEthUsd.setRoundID(1);

      // set price to invalid price
      await clEthUsd.setPrice(0);
      await expect(PriceCalculator.tokenToUSD(Ethereum, etherValue)).to.be.revertedWithCustomError(PriceCalculator, 'InvalidPrice');
      // reset to valid price
      await clEthUsd.setPrice(DEFAULT_ETH_USD_PRICE);

      // set updatedAt to invalid time
      await clEthUsd.setUpdatedAt(0);
      await expect(PriceCalculator.tokenToUSD(Ethereum, etherValue)).to.be.revertedWithCustomError(PriceCalculator, 'InvalidUpdate');
      // also invalid in future
      const now = Math.floor(new Date / 1000);
      const day = 60 * 60 * 24;
      await clEthUsd.setUpdatedAt(now + day);
      await expect(PriceCalculator.tokenToUSD(Ethereum, etherValue)).to.be.revertedWithCustomError(PriceCalculator, 'InvalidUpdate');
      // reset to valid updated at
      await clEthUsd.setPrice(now);

      // latest price is more than a day old
      await clEthUsd.setUpdatedAt(now - day - 1);
      await expect(PriceCalculator.tokenToUSD(Ethereum, etherValue)).to.be.revertedWithCustomError(PriceCalculator, 'StalePrice');
    });
  });

  describe('USDCToUSD', async () => {
    it('returns the USD 18 dec value of given USDC amount', async () => {
      const USDCAmount = 100_000_000 // $100
      expect(await PriceCalculator.USDCToUSD(USDCAmount, 6)).to.equal(ethers.utils.parseEther('100'));
    });
  });

  describe('validateSequencerUp', async () => {
    it('reverts if sequencer feed down', async () => {
      await sequencerFeed.setPrice(1);

      const USDCAmount = 100_000_000;
      const ethValue = ethers.utils.parseEther('1');
      await expect(PriceCalculator.USDCToUSD(USDCAmount, 6)).to.be.revertedWithCustomError(PriceCalculator, 'SequencerDown');
      await expect(PriceCalculator.tokenToUSD(Ethereum, ethValue)).to.be.revertedWithCustomError(PriceCalculator, 'SequencerDown');

      await sequencerFeed.setPrice(0);
      // sequencer only start 30 mins ago ... not yet valid
      const halfHour = 1800;
      await sequencerFeed.setStartedAt((await ethers.provider.getBlock('latest')).timestamp - halfHour);
    });
  });

  describe('setDataFeedTimeout', async () => {
    it('allows owner to set timeout for given feed', async () => {
      const other = (await ethers.getSigners())[1]
      const hour = 60 * 60;
      const ethValue = ethers.utils.parseEther('1');

      await clEthUsd.setUpdatedAt((await ethers.provider.getBlock('latest')).timestamp - hour);
      await expect(PriceCalculator.tokenToUSD(Ethereum, ethValue)).not.to.be.reverted;

      await expect(PriceCalculator.connect(other).setDataFeedTimeout(clEthUsd.address, hour)).to.be.revertedWith('Ownable: caller is not the owner');
      await expect(PriceCalculator.setDataFeedTimeout(clEthUsd.address, hour)).not.to.be.reverted;

      await expect(PriceCalculator.tokenToUSD(Ethereum, ethValue)).to.be.revertedWithCustomError(PriceCalculator, 'StalePrice');
    });
  });
});
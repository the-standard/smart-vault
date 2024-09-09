const { expect } = require('chai');
const { ethers } = require("hardhat");
const { ETH, DEFAULT_ETH_USD_PRICE } = require('./common');

let PriceCalculator, Ethereum, WBTC;

describe('PriceCalculator', async () => {
  beforeEach(async () => {
    const clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    await clEthUsd.setPrice(DEFAULT_ETH_USD_PRICE)
    const clWBTCUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
    await clWBTCUsd.setPrice(DEFAULT_ETH_USD_PRICE.mul(20))
    const clUSDCUSD = await (await ethers.getContractFactory('ChainlinkMock')).deploy('USDC / USD');
    await clUSDCUSD.setPrice(ethers.utils.parseUnits('1', 8));
    PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, clUSDCUSD.address);
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
    })
  });

  describe('USDCToUSD', async () => {
    it('returns the USD 18 dec value of given USDC amount', async () => {
      const USDCAmount = 100_000_000 // $100
      expect(await PriceCalculator.USDCToUSD(USDCAmount, 6)).to.equal(ethers.utils.parseEther('100'));
    })
  });
});
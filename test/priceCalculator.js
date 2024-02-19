const { expect } = require('chai');
const { ethers } = require("hardhat");
const { ETH, DEFAULT_EUR_USD_PRICE } = require('./common');
const { BigNumber } = ethers;

let PriceCalculator, Ethereum, WBTC;

describe('PriceCalculator', async () => {
  beforeEach(async () => {
    const now = Math.floor(new Date / 1000);
    const hour = 60 * 60;
    const ethPrices = [[now - 6 * hour, 200000000000], [now - 4 * hour, 150000000000], [now - 2 * hour, 140000000000], [now, 100000000000]];
    const clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    for (const round of ethPrices) {
      await clEthUsd.addPriceRound(round[0], round[1]);
    }

    const wbtcPrices = [[now - 6 * hour, 3700000000000], [now - 4 * hour, 3400000000000], [now - 2 * hour, 3700000000000], [now, 3400000000000]];
    const clWBTCUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('WBTC / USD');
    for (const round of wbtcPrices) {
      await clWBTCUsd.addPriceRound(round[0], round[1]);
    }
    const clEurUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('EUR / USD');
    await clEurUsd.setPrice(DEFAULT_EUR_USD_PRICE);
    PriceCalculator = await (await ethers.getContractFactory('PriceCalculator')).deploy(ETH, clEurUsd.address);
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

  describe('tokenToEur', async () => {
    it('returns the value of token in EUR based on the latest chainlink price', async () => {
      // latest ETH price is $1000
      // EUR / USD is 1.06
      const etherValue = ethers.utils.parseEther('1');
      let expectedEurValue = etherValue.mul(100000000000).div(106000000);
      let eurValue = await PriceCalculator.tokenToEur(Ethereum, etherValue);
      expect(eurValue).to.equal(expectedEurValue);

      // latest WBTC price is $34000
      // EUR / USD is 1.06
      const wbtcValue = BigNumber.from(50000000);
      expectedEurValue = wbtcValue.mul(BigNumber.from(10).pow(10)) // scale up for WBTC 8 dec
                                .mul(3400000000000).div(106000000);
      eurValue = await PriceCalculator.tokenToEur(WBTC, wbtcValue);
      expect(eurValue).to.equal(expectedEurValue);
    })
  });

  describe('eurToToken', async () => {
    it('returns the value of EUR in token based on the latest chainlink price', async () => {
      // latest ETH price is $1000
      // EUR / USD is 1.06
      const eurValue = ethers.utils.parseEther('1000');
      const expectedEthValue = eurValue.mul(106000000).div(100000000000);
      const ethValue = await PriceCalculator.eurToToken(Ethereum, eurValue);
      expect(ethValue).to.equal(expectedEthValue);

      // latest WBTC price is $34000
      // EUR / USD is 1.06
      const expectedWBTCValue = eurValue.div(BigNumber.from(10).pow(10)) // scale down for WBTC 8 dec
                                  .mul(106000000).div(3400000000000);
      const wbtcValue = await PriceCalculator.eurToToken(WBTC, eurValue);
      expect(wbtcValue).to.equal(expectedWBTCValue);
    })
  });
});
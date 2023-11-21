const { expect } = require('chai');
const { ethers } = require("hardhat");
const { ETH, DEFAULT_EUR_USD_PRICE } = require('./common');
const { BigNumber } = ethers;

let PriceCalculator, Ethereum;

describe('PriceCalculator', async () => {
  beforeEach(async () => {
    const now = Math.floor(new Date / 1000);
    const hour = 60 * 60;
    const ethPrices = [[now - 6 * hour, 200000000000], [now - 4 * hour, 150000000000], [now - 2 * hour, 140000000000], [now, 100000000000]];
    const clEthUsd = await (await ethers.getContractFactory('ChainlinkMock')).deploy('ETH / USD');
    for (const round of ethPrices) {
      await clEthUsd.addPriceRound(round[0], round[1]);
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
  });

  describe('tokenToEurAvg', async () => {
    it('calculates value of token in EUR based on chainlink average over 4 hours', async () => {
      // converting 1 ether to usd
      // avg. price eth / usd = (1500 + 1400 + 1000) / 3 = 1300
      // 1 ether = 1300 usd
      // avg. price eur / usd = (1.03 + 1.06 + 1.06) / 3 = 1.05
      // 1300 usd = ~1238.09 eur
      const etherValue = ethers.utils.parseEther('1');
      const averageEthUsd = BigNumber.from(150000000000).add(140000000000).add(100000000000).div(3);
      const expectedEurValue = etherValue.mul(averageEthUsd).div(DEFAULT_EUR_USD_PRICE);
      const eurValue = await PriceCalculator.tokenToEurAvg(Ethereum, etherValue);
      expect(eurValue).to.equal(expectedEurValue);
    });
  });

  describe('tokenToEur', async () => {
    it('returns the value of token in EUR based on the latest chainlink price', async () => {
      // latest ETH price is $1000
      // EUR / USD is 1.06
      const etherValue = ethers.utils.parseEther('1');
      const expectedEurValue = etherValue.mul(100000000000).div(106000000);
      const eurValue = await PriceCalculator.tokenToEur(Ethereum, etherValue);
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
    })
  });
});
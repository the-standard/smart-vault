require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require('hardhat-contract-sizer');
require('solidity-coverage')
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');

const { 
  INFURA_API_KEY, TEST_ACCOUNT_PRIVATE_KEY, ETHERSCAN_KEY, POLYGONSCAN_KEY,
  ALCHEMY_MUMBAI_KEY, ARBISCAN_KEY
} = process.env;
const testAccounts = TEST_ACCOUNT_PRIVATE_KEY ? [TEST_ACCOUNT_PRIVATE_KEY] : [];

module.exports = {
  solidity: "0.8.17",
  defaultNetwork: 'hardhat',
  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: testAccounts
    },
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: testAccounts
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_MUMBAI_KEY}`,
      accounts: testAccounts
    },
    polygon_zk_testnet: {
      url: 'https://rpc.public.zkevm-test.net',
      accounts: testAccounts
    },
    arbitrum_goerli: {
      url: 'https://goerli-rollup.arbitrum.io/rpc',
      chainId: 421613,
      accounts: testAccounts
    },
    arbitrum: {
      url: 'https://arbitrum.meowrpc.com',
      chainId: 42161,
      accounts: testAccounts
    }
  },
  etherscan: {
    apiKey: {
      goerli: ETHERSCAN_KEY,
      sepolia: ETHERSCAN_KEY,
      polygonMumbai: POLYGONSCAN_KEY,
      arbitrumGoerli: ARBISCAN_KEY
    }
  }
};
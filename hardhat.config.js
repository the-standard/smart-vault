require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require('hardhat-contract-sizer');
require('solidity-coverage')
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');

const { 
  INFURA_API_KEY, MAIN_ACCOUNT_PRIVATE_KEY, TEST_ACCOUNT_PRIVATE_KEY, ETHERSCAN_KEY,
  POLYGONSCAN_KEY, ALCHEMY_MUMBAI_KEY, ARBISCAN_KEY, ALCHEMY_ARBITRUM_KEY,
  ALCHEMY_ARBITRUM_GOERLI_KEY, ALCHEMY_ARBITRUM_SEPOLIA_KEY
} = process.env;
const testAccounts = TEST_ACCOUNT_PRIVATE_KEY ? [TEST_ACCOUNT_PRIVATE_KEY] : [];

module.exports = {
  solidity: "0.8.17",
  defaultNetwork: 'hardhat',
  networks: {
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [MAIN_ACCOUNT_PRIVATE_KEY]
    },
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
    arbitrum: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_ARBITRUM_KEY}`,
      accounts: [MAIN_ACCOUNT_PRIVATE_KEY]
    },
    arbitrum_sepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${ALCHEMY_ARBITRUM_SEPOLIA_KEY}`,
      accounts: testAccounts
    },
    // hardhat: {
    //   forking: {
    //     url: `https://arb-mainnet.g.alchemy.com/v2/${ALCHEMY_ARBITRUM_KEY}`,
    //   }
    // }
  },
  etherscan: {
    apiKey: {
      goerli: ETHERSCAN_KEY,
      sepolia: ETHERSCAN_KEY,
      polygonMumbai: POLYGONSCAN_KEY,
      arbitrumOne: ARBISCAN_KEY,
      arbitrumSepolia: ARBISCAN_KEY
    },
    customChains: [
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/"
        }
      }
    ]
  },
  mocha: {
    timeout: 1000000
  }
};
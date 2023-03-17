require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");
require('hardhat-contract-sizer');
require('solidity-coverage')
require("@nomiclabs/hardhat-etherscan");

const { INFURA_API_KEY, TEST_ACCOUNT_PRIVATE_KEY, ETHERSCAN_KEY } = process.env;
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
    polygon_zk_testnet: {
      url: 'https://rpc.public.zkevm-test.net',
      accounts: testAccounts
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_KEY,
  }
};
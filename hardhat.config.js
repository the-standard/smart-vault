require("@nomicfoundation/hardhat-toolbox");
require('hardhat-contract-sizer');
require('dotenv').config();

const { INFURA_API_KEY, TEST_ACCOUNT_PRIVATE_KEY } = process.env;
const testAccounts = TEST_ACCOUNT_PRIVATE_KEY ? [TEST_ACCOUNT_PRIVATE_KEY] : [];

module.exports = {
  solidity: "0.8.17",
  defaultNetwork: 'hardhat',
  networks: {
    goerli: {
      url: `https://goerli.infura.io/v3/${INFURA_API_KEY}`,
      accounts: testAccounts
    }
  },
};

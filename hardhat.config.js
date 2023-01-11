require("@nomicfoundation/hardhat-toolbox");
require('hardhat-contract-sizer');

module.exports = {
  solidity: "0.8.17",
  settings: {
    optimizer: {
      enabled: true,
      runs: 20
    },
  },
};

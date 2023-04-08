// require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.17",
        settings: {
            // viaIR: true,
        }
    },
    networks: {
        mumbai: {
            url: process.env.POLYGON_TESTNET_RPC,
            accounts: [process.env.PRIVATE_KEY],
            chainId: 80001
        },
        bnb: {
            url: process.env.BNB_TESTNET_RPC,
            accounts: [process.env.PRIVATE_KEY]
        },
    },
    etherscan: {
        apiKey: process.env.SCAN_API_KEY
    },
};
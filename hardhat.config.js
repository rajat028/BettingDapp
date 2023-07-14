require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter")
require("solidity-coverage")
require("dotenv").config()

const COIN_MARKET_CAP_API_KEY = process.env.COIN_MARKET_CAP_API_KEY
module.exports = {
	solidity: {
		version: "0.8.18",
		settings: {
			optimizer: {
				enabled: true,
				runs: 300,
			},
		},
	},
	gasReporter: {
		outputFile: "gas-report.txt",
		noColors: true,
		currency: "USD",
		coinmarketcap: COIN_MARKET_CAP_API_KEY,
		enabled: true,
	},
}

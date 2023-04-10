const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { number } = require("yargs");

const PRICE_PRECISION = 30;

describe("Vault Testing", function () {
    async function deployContracts() {

        const fbtcContract = await ethers.getContractFactory("FBTC");
        const fbtc = await fbtcContract.deploy();
        await fbtc.deployed();
        const fethContract = await ethers.getContractFactory("FETH");
        const feth = await fethContract.deploy();
        await feth.deployed();
        const fdaiContract = await ethers.getContractFactory("FDAI");
        const fdai = await fdaiContract.deploy();
        await fdai.deployed();
        const flinkContract = await ethers.getContractFactory("FLINK");
        const flink = await flinkContract.deploy();
        await flink.deployed();
        console.log("Token deployed!")
        console.log(`
            btc: ${fbtc.address}, 
            eth: ${feth.address}, 
            dai: ${fdai.address}, 
            link: ${flink.address}
        `);
        console.log("-------------------------------\n");

        const priceFeedContract = await ethers.getContractFactory("PriceFeed");
        const fbtcPriceFeed = await priceFeedContract.deploy("0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43");
        await fbtcPriceFeed.deployed();
        const fethPriceFeed = await priceFeedContract.deploy("0x694AA1769357215DE4FAC081bf1f309aDC325306");
        await fethPriceFeed.deployed();
        const fdaiPriceFeed = await priceFeedContract.deploy("0x14866185B1962B63C3Ea9E03Bc1da838bab34C19");
        await fdaiPriceFeed.deployed();
        const flinkPriceFeed = await priceFeedContract.deploy("0xc59E3633BAAC79493d908e63626716e204A45EdF");
        await flinkPriceFeed.deployed();
        console.log("PriceFeed deployed!");
        console.log("-------------------------------\n");

        const tokenUtilsContract = await ethers.getContractFactory("TokenUtils");
        const tokenUtils = await tokenUtilsContract.deploy();
        await tokenUtils.deployed();
        console.log("TokenUtils deployed!");
        await tokenUtils.setPriceFeed(fbtc.address, fbtcPriceFeed.address);
        await tokenUtils.setPriceFeed(feth.address, fethPriceFeed.address);
        await tokenUtils.setPriceFeed(fdai.address, fdaiPriceFeed.address);
        await tokenUtils.setPriceFeed(flink.address, flinkPriceFeed.address);
        console.log("TokenUtils: settings for price feed done!");

        await tokenUtils.setDecimals(fbtc.address, 8);
        await tokenUtils.setDecimals(feth.address, 18);
        await tokenUtils.setDecimals(fdai.address, 18);
        await tokenUtils.setDecimals(flink.address, 18);
        console.log("TokenUtils: settings for decimals done!");

        await tokenUtils.setStableToken(fbtc.address);
        await tokenUtils.setStableToken(feth.address);
        console.log("TokenUtils: settings for stable token done!");

        await tokenUtils.setWhiteListToken(fbtc.address);
        await tokenUtils.setWhiteListToken(feth.address);
        await tokenUtils.setWhiteListToken(fdai.address);
        await tokenUtils.setWhiteListToken(flink.address);
        console.log("TokenUtils: settings for whitelist token done!");
        console.log("-------------------------------\n");


        const feeManagerContract = await ethers.getContractFactory("FeeManager");
        const feeManager = await feeManagerContract.deploy();
        await feeManager.deployed();
        console.log("FeeManager deployed!");
        console.log("-------------------------------\n");

        const vaultContract = await ethers.getContractFactory("Vault");
        const vault = await vaultContract.deploy();
        await vault.deployed();
        console.log("Vault deployed!");
        await vault.initialization(tokenUtils.address, feeManager.address);
        console.log("Vault initialized!");
        console.log("-------------------------------\n");

        const lpManagerContract = await ethers.getContractFactory("LPManager");
        const lpManager = await lpManagerContract.deploy();
        await lpManager.deployed();
        console.log("LPManager deployed!");
        await lpManager.initialization(vault.address);
        console.log("LPManager initialized!");
        console.log("-------------------------------\n");

        return { fbtc, feth, fdai, flink, fbtcPriceFeed, fethPriceFeed, fdaiPriceFeed, flinkPriceFeed, vault, lpManager, tokenUtils };
    }

    describe("Prequisition", function () {
        it("Should be deployed successfully", async function () {
            const { fbtc, feth, fdai, flink, vault } = await loadFixture(deployContracts);
            expect(1).to.equal(1);
        });
    });

    describe("IncreasePosition", function () {
        it("Should increase position successfully", async function () {
            const {
                fbtc, feth, fdai, flink, fbtcPriceFeed, fethPriceFeed, fdaiPriceFeed, flinkPriceFeed, vault, lpManager, tokenUtils
            } = await loadFixture(deployContracts);
            const [owner, user1, lp1, account3] = await ethers.getSigners();

            const btcDecimal = await tokenUtils.getDecimal(fbtc.address);
            const btcPrice = 18000;
            const ethPrice = 1800;

            // lp1 configurations
            const fbtcTotalSupply = 1000 * (10 ** btcDecimal);
            const usedFbtcSupply = 500 * (10 ** btcDecimal);

            // user1 configurations
            const fbtcTotalCollateral = 100 * (10 ** btcDecimal);
            const usedFbtcCollateral = 20 * (10 ** btcDecimal);
            const usedFbtcLeverage = 10;

            // step 1: deposite token with lp account
            await fbtc.connect(owner).mint(lp1.address, fbtcTotalSupply);
            await fbtc.connect(lp1).transfer(lpManager.address, usedFbtcSupply);
            await lpManager.connect(lp1).deposite(lp1.address, fbtc.address, usedFbtcSupply);

            expect(await fbtc.balanceOf(lp1.address)).to.equal(fbtcTotalSupply - usedFbtcSupply);
            expect(await fbtc.balanceOf(vault.address)).to.equal(usedFbtcSupply);
            console.log("----------- Deposition done!");

            // step 2: transfer collateral tokens into vault account
            await fbtc.connect(owner).mint(user1.address, fbtcTotalCollateral);
            await fbtc.connect(user1).transfer(vault.address, usedFbtcCollateral);

            expect(await fbtc.balanceOf(user1.address)).to.equal(fbtcTotalCollateral - usedFbtcCollateral);
            expect(await fbtc.balanceOf(vault.address)).to.equal(usedFbtcCollateral + usedFbtcSupply);

            // step 3: set faucet price for collateral and index token
            await fbtcPriceFeed.setFaucetPrice(btcPrice);
            await fethPriceFeed.setFaucetPrice(ethPrice);
            console.log("----------- Preparation for increase position done!");

            // step 4: increase position
            await vault.connect(user1).increasePosition(
                user1.address,
                fbtc.address,
                feth.address,
                usedFbtcCollateral * usedFbtcLeverage * btcPrice / (10 ** btcDecimal),
                false
            );
        });
    });
    describe("DecreasePosition", function () { });
    describe("LiquidatePosition", function () { });
});
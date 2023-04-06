// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeed {
    AggregatorV3Interface internal aggregator;

    /**
     * Network: Sepolia
     * Aggregator: BTC/USD
     * Address: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
     */
    constructor() {
        aggregator = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
    }

    // get latest price
    function getLatestPrice() public view returns (uint80, uint, int) {
        // prettier-ignore
        (
        uint80 roundID,
        int price,
        /*uint startedAt*/,
        uint timeStamp,
        /*uint80 answeredInRound*/
        ) = aggregator.latestRoundData();
        return (roundID, timeStamp, price);
    }

    // get historical price
    function getRoundData(uint80 roundId) public view returns (uint256, int) {
        // prettier-ignore
        (
        /*uint80 roundID*/,
        int price,
        /*uint startedAt*/,
        uint timeStamp,
        /*uint80 answeredInRound*/
        ) = aggregator.getRoundData(roundId);
        require(timeStamp > 0, "Round not complete");
        return (timeStamp, price);
    }
}

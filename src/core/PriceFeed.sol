// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IPriceFeed.sol";

contract PriceFeed is IPriceFeed {
    using SafeMath for uint256;

    AggregatorV3Interface internal aggregator;

    int256 public answer;
    uint80 public roundId;
    uint256 public lastUpdateTimestamp;
    uint256 public updateInterval = 1 hours;
    uint256 public PRICE_PRECISION = 30;
    mapping(uint80 => int256) public answers;
    mapping(address => bool) public isAdmin;

    /**
     * Network: Sepolia
     *
     * BTC/USD: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
     * ETH/USD: 0x694AA1769357215DE4FAC081bf1f309aDC325306
     * DAI/USD: 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19
     * LINK/USD: 0xc59E3633BAAC79493d908e63626716e204A45EdF
     */
    constructor(address aggregator_) {
        aggregator = AggregatorV3Interface(aggregator_);
        lastUpdateTimestamp = block.timestamp;
        isAdmin[msg.sender] = true;
    }

    // check upkeep function, time trigger
    function shouldUpdate() external view returns (bool) {
        return (block.timestamp >= (lastUpdateTimestamp + updateInterval));
    }

    // perform upkeep function, update price periodically
    function updatePrice() external {
        require(isAdmin[msg.sender], "PriceFeed: forbidden");
        (
            /* uint80 roundID */
            ,
            int256 price,
            /* startedAt */
            ,
            uint256 timestamp,
            /* answeredInRound */
        ) = aggregator.latestRoundData();
        require(timestamp > 0, "Round not complete");
        if (price != answer) {
            answer = price;
            roundId = roundId + 1;
            lastUpdateTimestamp = timestamp;
            answers[roundId] = price;
        }
    }

    function getRoundId() external view returns (uint256) {
        return uint256(roundId);
    }

    function getLatestAnswer() external view override returns (uint256) {
        return uint256(answer).mul(10 ** PRICE_PRECISION);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";
import "./interface/IPriceFeed.sol";

contract PriceFeedKeeper is AutomationCompatibleInterface {
    constructor() {}

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (address[] memory priceFeeds) = abi.decode(checkData, (address[]));
        uint256 checkLength = priceFeeds.length;
        require(checkLength > 0, "PriceFeedKeeper: checkLength == 0");

        bool upKeepNeeded = false;

        // counter of price feeds need to be performed
        uint256 upKeepCounter = 0;
        for (uint256 i = 0; i < checkLength;) {
            if (IPriceFeed(priceFeeds[i]).shouldUpdate()) {
                upKeepNeeded = true;
            }
            unchecked {
                upKeepCounter = upKeepCounter + 1;
                i = i + 1;
            }
        }

        // collect price feeds need to be performed
        upKeepNeeded = false;
        address[] memory upKeepAddresses = new address[](upKeepCounter);
        uint256 indice = 0;
        for (uint256 i = 0; i < checkLength;) {
            if (IPriceFeed(priceFeeds[i]).shouldUpdate()) {
                upKeepNeeded = true;
                upKeepAddresses[indice] = priceFeeds[i];
                unchecked {
                    indice = indice + 1;
                    i = i + 1;
                }
            }
        }

        // pack addresses and hand them over to performUpKeep
        performData = abi.encode(upKeepAddresses);
        return (upKeepNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        (address[] memory priceFeeds) = abi.decode(performData, (address[]));
        uint256 performLength = priceFeeds.length;
        require(performLength > 0, "PriceFeedKeeper: performLength == 0");

        // update price here
        for (uint256 i = 0; i < performLength;) {
            IPriceFeed(priceFeeds[i]).updatePrice();
        }
    }
}

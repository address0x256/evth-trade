// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../node_modules/@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract PriceFeedKeeper is AutomationCompatibleInterface {
    constructor() {}

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (false, "");
    }

    function performUpkeep(bytes calldata performData) external override {}
}

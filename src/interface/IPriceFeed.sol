// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPriceFeed {
    function shouldUpdate() external view returns (bool);
    function updatePrice() external;
    function getRoundId() external view returns (uint80);
    function getLatestAnswer() external view returns (int256);
}

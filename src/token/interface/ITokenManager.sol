// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITokenManager {
    function getToken(string memory _name) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./FBTC.sol";
import "./FETH.sol";
import "./FDAI.sol";
import "./FLINK.sol";

contract TokenManager {
    mapping(string => address) name2token;

    // already exists before on-chain
    constructor() {
        name2token["FBTC"] = address(new FBTC());
        name2token["FETH"] = address(new FETH());
        name2token["FDAI"] = address(new FDAI());
        name2token["FLINK"] = address(new FLINK());
    }

    function getToken(string memory _name) external view returns (address) {
        return name2token[_name];
    }
}

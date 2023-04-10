// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    function getToken(string memory _name) public view returns (address) {
        return name2token[_name];
    }

    function mintToken(string memory _name, address _account, uint256 _amount) external {
        require(_account != address(0), "mintToken: address == 0");

        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("FBTC"))) {
            FBTC(getToken(_name)).mint(_account, _amount);
        }
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("FETH"))) {
            FETH(getToken(_name)).mint(_account, _amount);
        }
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("FDAI"))) {
            FDAI(getToken(_name)).mint(_account, _amount);
        }
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked("FLINK"))) {
            FLINK(getToken(_name)).mint(_account, _amount);
        }
    }

    function getBalance(string memory _name, address _account) external view returns (uint256) {
        return IERC20(getToken(_name)).balanceOf(_account);
    }

    function transfer(string memory _name, address _from, address _to, uint256 _amount) external {
        IERC20(getToken(_name)).transferFrom(_from, _to, _amount);
    }
}

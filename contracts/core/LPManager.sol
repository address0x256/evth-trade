// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IVault.sol";

contract LPManager {
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) lpPositions;

    IVault vault;

    constructor() {}

    function initialization(address _vault) public {
        vault = IVault(_vault);
    }

    function deposite(address _account, address _token, uint256 _amount) external {
        IERC20(_token).transfer(address(vault), _amount);
        vault.deposite(_token);
        lpPositions[_account][_token] = lpPositions[_account][_token].add(_amount);
    }

    function withdraw() external {}
}

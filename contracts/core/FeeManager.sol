// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IFeeManager.sol";

/**
 * This contract is used for managing fees
 */
contract FeeManager is IFeeManager {
    using SafeMath for uint256;

    uint256 BASIS_POINTS_DIVISOR = 10000;
    uint256 _positionFeePoints = 20;

    // amount of tokens fees consumed
    mapping(address => uint256) public feeReserves;

    constructor() {}

    function setPositionFeePoints(uint256 _feePoints) external {
        _positionFeePoints = _feePoints;
    }

    function getPositionFee(uint256 _sizeDelta) external view returns (uint256) {
        if (_sizeDelta == 0) return 0;
        uint256 afterFeeUsd = _sizeDelta.mul(BASIS_POINTS_DIVISOR.sub(_positionFeePoints)).div(BASIS_POINTS_DIVISOR);
        uint256 positionFee = _sizeDelta.sub(afterFeeUsd);

        return positionFee;
    }

    function updateFeeReserves(address _token, uint256 _amount) external {
        require(_token != address(0), "FeeManager: token == 0");
        require(_amount > 0, "FeeManager: amount == 0");
        feeReserves[_token] = feeReserves[_token].add(_amount);
    }
}

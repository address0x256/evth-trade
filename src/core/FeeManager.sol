// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interface/IFeeManager.sol";

contract FeeManager is IFeeManager {
    using SafeMath for uint256;

    uint256 BASIS_POINTS_DIVISOR = 10000;
    uint256 _positionFeePoints = 20;

    // amount of tokens fees consumed
    mapping(address => uint256) public feeReserves;

    constructor() {}

    function setPositionFeePoints(uint256 _feePoints) public {
        _positionFeePoints = _feePoints;
    }

    function getPositionFee(uint256 _sizeDelta) public view returns (uint256) {
        if (_sizeDelta == 0) return 0;
        uint256 afterFeeUsd = _sizeDelta.mul(BASIS_POINTS_DIVISOR.sub(_positionFeePoints)).div(BASIS_POINTS_DIVISOR);
        return _sizeDelta.sub(afterFeeUsd);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFeeManager {
    function getPositionFee(uint256 _sizeDelta) external view returns (uint256);
    function updateFeeReserves(address _token, uint256 _amount) external;
}

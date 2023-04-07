// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITokenUtils {
    function getPrice(address _token) external view returns (uint256);
    function getDecimal(address _token) external view returns (uint256);
    function validPositionToken(address _collateralToken, address _indexToken, bool _isLong) external view;
}

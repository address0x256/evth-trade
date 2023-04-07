// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITokenUtils {
    function getPrice(address _token) external view returns (uint256);
    function getDecimal(address _token) external view returns (uint256);
    function tokenToUsd(address _token, uint256 _tokenAmount) external view returns (uint256);
    function usdToToken(address _token, uint256 _usdAmount) external view returns (uint256);
    function validPositionToken(address _collateralToken, address _indexToken, bool _isLong) external view;
}

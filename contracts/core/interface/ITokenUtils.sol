// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ITokenUtils {
    function getPrice(address _token) external view returns (uint256);
    function getDecimal(address _token) external view returns (uint256);
    function getAdjustedSize(address _token, uint256 _size) external view returns (uint256);
    function getAdjustedAmount(address _token, uint256 _amount) external view returns (uint256);
    function getAdjustedUsd(address _collateralToken, address _indexToken, uint256 _fee)
        external
        view
        returns (uint256);
    function isWhiteListToken(address _token) external view returns (bool);
    function isStableToken(address _token) external view returns (bool);
    function tokenToUsd(address _token, uint256 _tokenAmount) external view returns (uint256);
    function usdToToken(address _token, uint256 _usdAmount) external view returns (uint256);
    function validPositionToken(address _collateralToken, address _indexToken, bool _isLong) external view;
}

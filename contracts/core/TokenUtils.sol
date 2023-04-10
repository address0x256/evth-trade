// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../token/interface/ITokenManager.sol";
import "./interface/IPriceFeed.sol";
import "./interface/ITokenUtils.sol";
import "./PriceFeed.sol";

/**
 * This contract is purely used for query and vaidation
 */
contract TokenUtils is ITokenUtils {
    using SafeMath for uint256;

    ITokenManager tokenManager;

    // token address => price feed
    mapping(address => address) tokenPriceFeed;
    // token address => decimal
    mapping(address => uint256) tokenDecimal;
    // token whitelist
    mapping(address => bool) public whitelistToken;
    // token stable
    mapping(address => bool) public stableToken;

    function setPriceFeed(address _token, address _feed) external {
        tokenPriceFeed[_token] = _feed;
    }

    function setDecimals(address _token, uint256 _decimal) external {
        tokenDecimal[_token] = _decimal;
    }

    function setStableToken(address _token) public {
        require(_token != address(0), "setStableToken: address == 0");
        stableToken[_token] = true;
    }

    function setWhiteListToken(address _token) public {
        require(_token != address(0), "setWhiteListToken: address == 0");
        whitelistToken[_token] = true;
    }

    function isWhiteListToken(address _token) external view returns (bool) {
        return whitelistToken[_token];
    }

    function isStableToken(address _token) external view returns (bool) {
        return stableToken[_token];
    }

    function getDecimal(address _token) public view returns (uint256) {
        return tokenDecimal[_token];
    }

    // unit price
    function getPrice(address _token) public view returns (uint256) {
        uint256 price = IPriceFeed(tokenPriceFeed[_token]).getLatestAnswer();
        uint256 decimal = getDecimal(_token);
        return price.div(10 ** decimal);
    }

    function getAdjustedSize(address _token, uint256 _size) external view returns (uint256) {
        uint256 precision = IPriceFeed(tokenPriceFeed[_token]).getPricePrecision();
        uint256 decimal = getDecimal(_token);
        return _size.mul(10 ** precision).div(10 ** decimal);
    }

    function getAdjustedAmount(address _token, uint256 _amount) external view returns (uint256) {
        uint256 decimal = getDecimal(_token);
        return _amount.mul(10 ** decimal);
    }

    function getAdjustedUsd(address _collateralToken, address _indexToken, uint256 _usdAmount)
        external
        view
        returns (uint256)
    {
        uint256 indexDecimal = getDecimal(_indexToken);
        uint256 collateralDecimal = getDecimal(_collateralToken);
        return _usdAmount.mul(10 ** indexDecimal).div(10 ** collateralDecimal);
    }

    function tokenToUsd(address _token, uint256 _tokenAmount) public view returns (uint256) {
        if (_tokenAmount == 0) return 0;
        uint256 price = getPrice(_token);
        uint256 decimals = getDecimal(_token);
        return _tokenAmount.mul(price).div(10 ** decimals);
    }

    function usdToToken(address _token, uint256 _usdAmount) public view returns (uint256) {
        if (_usdAmount == 0) return 0;
        uint256 decimals = getDecimal(_token);
        uint256 price = getPrice(_token);
        if (price == 0) {
            return 0;
        }
        return _usdAmount.mul(10 ** decimals).div(price);
    }

    function validPositionToken(address _collateralToken, address _indexToken, bool _isLong) external view {
        require(_collateralToken != address(0), "_validIncreasePositionToken: _collateralToken = 0");
        if (_isLong) {
            require(_collateralToken == _indexToken, "_validIncreasePositionToken: _collateralToken != _indexToken");
            require(whitelistToken[_indexToken], "_validIncreasePositionToken: index is not whitelist token");
        } else {
            require(_collateralToken != _indexToken, "_validIncreasePositionToken: _collateralToken == _indexToken");
            require(stableToken[_collateralToken], "_validIncreasePositionToken: not stable token");
            require(whitelistToken[_indexToken], "_validIncreasePositionToken: not whitelist token");
        }
    }
}

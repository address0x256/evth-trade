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

    // already exists before on-chain
    constructor(address _tokenManager) {
        tokenManager = ITokenManager(_tokenManager);
    }

    // need to trigger it on-chain
    function initialization() external {
        // price feed
        tokenPriceFeed[tokenManager.getToken("FBTC")] =
            address(new PriceFeed(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43));
        tokenPriceFeed[tokenManager.getToken("FETH")] =
            address(new PriceFeed(0x694AA1769357215DE4FAC081bf1f309aDC325306));
        tokenPriceFeed[tokenManager.getToken("FDAI")] =
            address(new PriceFeed(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19));
        tokenPriceFeed[tokenManager.getToken("FLINK")] =
            address(new PriceFeed(0x14866185B1962B63C3Ea9E03Bc1da838bab34C19));

        // decimals
        tokenDecimal[tokenManager.getToken("FBTC")] = 8;
        tokenDecimal[tokenManager.getToken("FETH")] = 18;
        tokenDecimal[tokenManager.getToken("FDAI")] = 18;
        tokenDecimal[tokenManager.getToken("FLINK")] = 18;
    }

    // price from chainlink
    function getPrice(address _token) public view returns (uint256) {
        return IPriceFeed(tokenPriceFeed[_token]).getLatestAnswer();
    }

    function getDecimal(address _token) public view returns (uint256) {
        return tokenDecimal[_token];
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

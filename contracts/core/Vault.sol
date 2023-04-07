// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interface/ITokenUtils.sol";
import "./interface/IVault.sol";
import "./interface/IFeeManager.sol";

contract Vault is ReentrancyGuard, IVault {
    using SafeMath for uint256;

    struct Position {
        uint256 size;
        uint256 collateral;
        uint256 averagePrice;
        uint256 entryFundingRate;
        uint256 reserveAmount;
        int256 realisedPnl;
        uint256 lastIncreasedTime;
    }

    address gov;
    // manager
    mapping(address => bool) public isManager;

    // token related utils
    ITokenUtils tokenUtils;
    // fee related
    IFeeManager feeManager;

    // tokenBalances is used only to determine _transferIn values
    mapping(address => uint256) public tokenBalances;

    // amount of tokens available in pool, fees not included
    mapping(address => uint256) public poolAmounts;

    // amount of tokens actually opened, fees not included
    mapping(address => uint256) public reservedAmounts;

    // positions for users
    mapping(bytes32 => Position) public positions;

    event IncreaseReservedAmount(address token, uint256 amount);

    modifier onlyGov() {
        require(msg.sender == gov, "Vauld: not gov");
        _;
    }

    constructor() {
        gov = msg.sender;
        isManager[msg.sender] = true;
    }

    function setManager(address _manager) public onlyGov {
        isManager[_manager] = true;
    }

    function initialization(address _tokenUtils, address _feeManager) public {
        tokenUtils = ITokenUtils(_tokenUtils);
        feeManager = IFeeManager(_feeManager);
    }

    function getPositionKey(address _account, address _collateralToken, address _indexToken, bool _isLong)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_account, _collateralToken, _indexToken, _isLong));
    }

    function getDelta(address _token, uint256 _size, uint256 _averagePrice, bool _isLong)
        public
        view
        returns (bool, uint256)
    {
        require(_averagePrice > 0, "getDelta: averagPrice == 0");
        uint256 price = tokenUtils.getPrice(_token);
        uint256 priceDelta = _averagePrice > price ? _averagePrice.sub(price) : price.sub(_averagePrice);
        uint256 delta = _size.mul(priceDelta).div(_averagePrice);

        bool hasProfit = false;
        if (_isLong) {
            hasProfit = price > _averagePrice;
        } else {
            hasProfit = _averagePrice > price;
        }

        return (hasProfit, delta);
    }

    function getNextAveragePrice(
        address _token,
        uint256 _size,
        uint256 _averagePrice,
        bool _isLong,
        uint256 _nextPrice,
        uint256 _sizeDelta
    ) public view returns (uint256) {
        (bool hasProfit, uint256 delta) = getDelta(_token, _size, _averagePrice, _isLong);
        uint256 nextSize = _size.add(_sizeDelta);
        uint256 divisor;
        if (_isLong) {
            divisor = hasProfit ? nextSize.add(delta) : nextSize.sub(delta);
        } else {
            divisor = hasProfit ? nextSize.sub(delta) : nextSize.add(delta);
        }
        return _nextPrice.mul(nextSize).div(divisor);
    }

    function _transferIn(address _token) private returns (uint256) {
        uint256 prevBalance = tokenBalances[_token];
        uint256 nextBalance = IERC20(_token).balanceOf(address(this));
        tokenBalances[_token] = nextBalance;

        return nextBalance.sub(prevBalance);
    }

    function _transferOut(address _token, uint256 _amount, address _receiver) private {
        IERC20(_token).transfer(_receiver, _amount);
        tokenBalances[_token] = IERC20(_token).balanceOf(address(this));
    }

    function _increaseReservedAmount(address _token, uint256 _amount) private {
        reservedAmounts[_token] = reservedAmounts[_token].add(_amount);
        require(reservedAmounts[_token] <= poolAmounts[_token], "_increaseReservedAmount: ");
        emit IncreaseReservedAmount(_token, _amount);
    }

    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external nonReentrant {
        require(_account != address(0), "increasePosition: account == 0");
        require(_sizeDelta > 0, "increasePosition: _sizeDelta == 0");
        tokenUtils.validPositionToken(_collateralToken, _indexToken, _isLong);

        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position storage position = positions[key];

        // step 1: average price
        uint256 price = tokenUtils.getPrice(_indexToken);
        if (position.size == 0) {
            position.averagePrice = price;
        }
        if (position.size > 0 && _sizeDelta > 0) {
            position.averagePrice =
                getNextAveragePrice(_indexToken, position.size, position.averagePrice, _isLong, price, _sizeDelta);
        }

        // step 2: collateral
        uint256 totalFees = 0;
        uint256 positionFee = feeManager.getPositionFee(_sizeDelta);
        totalFees.add(positionFee);

        // nothing else included into totalFees for simplicity
        uint256 feeTokens = tokenUtils.usdToToken(_collateralToken, totalFees);
        feeManager.updateFeeReserves(_collateralToken, feeTokens);

        // add collateral if necessary
        uint256 collateralDelta = _transferIn(_collateralToken);
        uint256 collateralDeltaUsd = tokenUtils.tokenToUsd(_collateralToken, collateralDelta);
        position.collateral = position.collateral.add(collateralDeltaUsd);

        // update collateral
        position.collateral = position.collateral.sub(totalFees);

        // step 3: size
        position.size = position.size.add(_sizeDelta);

        // step 4: reserve
        uint256 reserveDelta = tokenUtils.usdToToken(_collateralToken, _sizeDelta);
        position.reserveAmount = position.reserveAmount.add(reserveDelta);

        // update global amount of opening token, either long or short
        _increaseReservedAmount(_collateralToken, reserveDelta);
    }

    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external nonReentrant {}

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external nonReentrant {}

    function swap(address _tokenIn, address _tokenOut, address _receiver) external nonReentrant {}
}

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

    // max leverage
    uint256 maxLeverage = 20;

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
    event DecreaseReservedAmount(address token, uint256 amount);

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

    function _decreaseReservedAmount(address _token, uint256 _amount) private {
        reservedAmounts[_token] = reservedAmounts[_token].sub(_amount, "Vault: insufficient reserve");
        emit DecreaseReservedAmount(_token, _amount);
    }

    /**
     * increase position or collateral
     */
    function increasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _sizeDelta,
        bool _isLong
    ) external nonReentrant {
        require(_account != address(0), "increasePosition: account == 0");
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
        {
            uint256 positionFee = feeManager.getPositionFee(_sizeDelta);
            totalFees.add(positionFee);
        }

        // nothing else included into totalFees for simplicity
        {
            uint256 feeTokens = tokenUtils.usdToToken(_collateralToken, totalFees);
            feeManager.updateFeeReserves(_collateralToken, feeTokens);
        }

        // add collateral if necessary
        {
            uint256 collateralDelta = _transferIn(_collateralToken);
            uint256 collateralDeltaUsd = tokenUtils.tokenToUsd(_collateralToken, collateralDelta);
            position.collateral = position.collateral.add(collateralDeltaUsd);
        }

        // update collateral
        position.collateral = position.collateral.sub(totalFees);

        // step 3: size
        position.size = position.size.add(_sizeDelta);
        require(position.collateral.mul(maxLeverage) >= position.size, "_validateLeverage: liquidation risk");

        // step 4: reserve
        uint256 reserveDelta = tokenUtils.usdToToken(_collateralToken, _sizeDelta);
        position.reserveAmount = position.reserveAmount.add(reserveDelta);
        position.lastIncreasedTime = block.timestamp;

        // update global amount of opening token, either long or short
        _increaseReservedAmount(_collateralToken, reserveDelta);
    }

    function _reduceCollateral(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong
    ) private returns (uint256 _outUsd, uint256 _totalFees) {
        Position storage position;
        {
            bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
            position = positions[key];
        }

        // amount of token need to be transferred out
        bool hasProfit;
        uint256 realizedPnL;
        {
            (bool _hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong);
            hasProfit = _hasProfit;
            realizedPnL = delta.mul(_sizeDelta).div(position.size);
        }

        // compute net collateral delta
        {
            uint256 netCollateralDelta = 0;
            {
                uint256 positionFee = feeManager.getPositionFee(_sizeDelta);
                _totalFees.add(positionFee);
            }
            if (_sizeDelta == position.size) {
                // clear the position
                netCollateralDelta = position.collateral;
                _outUsd = position.collateral;
                require(_outUsd >= _totalFees, "_reduceCollateral: colllateral cannot cover fees");
                if (!hasProfit) {
                    require(_outUsd >= (realizedPnL.add(_totalFees)), "_reduceCollateral: collateral cannot cover loss");
                }
                _outUsd =
                    hasProfit ? _outUsd.add(realizedPnL).sub(_totalFees) : _outUsd.sub(realizedPnL).sub(_totalFees);
            } else {
                // partially decrease position
                netCollateralDelta = _collateralDelta;
                if (hasProfit == true) {
                    if (realizedPnL >= _totalFees) {
                        _outUsd = realizedPnL.sub(_totalFees);
                    } else {
                        _outUsd = realizedPnL;
                        netCollateralDelta = netCollateralDelta.add(_totalFees);
                    }
                } else {
                    netCollateralDelta = netCollateralDelta.add(realizedPnL).add(_totalFees);
                }
            }

            // deduct net collateral delta
            if (position.collateral >= netCollateralDelta) {
                position.collateral = position.collateral.sub(netCollateralDelta);
            } else {
                require(1 == 0, "decreasePosition: liquidation risk");
            }
        }
        // update pool amount
        uint256 pnlAmount = tokenUtils.usdToToken(_collateralToken, realizedPnL);
        poolAmounts[_collateralToken] =
            hasProfit ? poolAmounts[_collateralToken].sub(pnlAmount) : poolAmounts[_collateralToken].add(pnlAmount);

        return (_outUsd, _totalFees);
    }

    /**
     * descrease position or collateral
     */
    function _decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) internal nonReentrant {
        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position storage position = positions[key];
        uint256 currentSize = position.size;

        require(currentSize > 0, "decreasePosition: size == 0");
        require(currentSize >= _sizeDelta, "decreasePosition: sizeDelta too big");
        require(position.collateral >= _collateralDelta, "decreasePosition: collateralDelta too big");

        // step 1: update reserve
        {
            uint256 reserveDelta = position.reserveAmount.mul(_sizeDelta).div(currentSize);
            position.reserveAmount = position.reserveAmount.sub(reserveDelta);
            _decreaseReservedAmount(_collateralToken, reserveDelta);
        }

        // step 2: update collateral
        (uint256 outUsd, uint256 totalFees) =
            _reduceCollateral(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong);

        // step 3: update global fee reserve
        {
            uint256 feeTokens = tokenUtils.usdToToken(_collateralToken, totalFees);
            feeManager.updateFeeReserves(_collateralToken, feeTokens);
        }

        // step 4: update size
        position.size = currentSize.sub(_sizeDelta);
        require(position.collateral.mul(maxLeverage) >= position.size, "_validateLeverage: liquidation risk");

        // step 5: transfer out
        uint256 outTokenAmount = 0;
        if (outUsd > 0) {
            uint256 profitAmount = tokenUtils.usdToToken(_collateralToken, outUsd);
            outTokenAmount = outTokenAmount.add(profitAmount);
        }
        if (currentSize > _sizeDelta) {
            if (_collateralDelta > 0) {
                uint256 deltaAmount = tokenUtils.usdToToken(_collateralToken, _collateralDelta);
                outTokenAmount = outTokenAmount.add(deltaAmount);
            }
        } else {
            delete positions[key];
        }
        if (outTokenAmount > 0) {
            _transferOut(_collateralToken, outTokenAmount, _receiver);
        }
    }

    function decreasePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver
    ) external nonReentrant {
        require(_account != address(0), "decreasePosition: account == 0");
        tokenUtils.validPositionToken(_collateralToken, _indexToken, _isLong);
        _decreasePosition(_account, _collateralToken, _indexToken, _collateralDelta, _sizeDelta, _isLong, _receiver);
    }

    /**
     * 0: passive liquidation, collateral will never be returned
     * 1: passive liquidation, collateral will be returned
     * 2: active liquidation on user's will
     */
    function _getLiquidationLevel(address _account, address _collateralToken, address _indexToken, bool _isLong)
        private
        view
        returns (uint256 _level, uint256 _feesToPay)
    {
        Position storage position;
        {
            bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
            position = positions[key];
        }

        uint256 remainedCollateral = 0;
        // fees
        {
            uint256 positionFee = feeManager.getPositionFee(position.size);
            _feesToPay.add(positionFee);
        }
        if (position.collateral < _feesToPay) {
            _level = 0;
            return (_level, _feesToPay);
        }

        // loss
        remainedCollateral = remainedCollateral.add(position.collateral.sub(_feesToPay));
        (bool hasProfit, uint256 delta) = getDelta(_indexToken, position.size, position.averagePrice, _isLong);
        if (!hasProfit && (position.collateral < _feesToPay.add(delta))) {
            _level = 0;
            return (_level, _feesToPay);
        }

        // leverage
        remainedCollateral = hasProfit ? remainedCollateral.add(delta) : remainedCollateral.sub(delta);
        if (remainedCollateral.mul(maxLeverage) < position.size) {
            _level = 1;
            return (_level, _feesToPay);
        }
        _level = 2;
        return (_level, _feesToPay);
    }

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _receiver
    ) external nonReentrant {
        require(_account != address(0), "decreasePosition: account == 0");
        tokenUtils.validPositionToken(_collateralToken, _indexToken, _isLong);

        bytes32 key = getPositionKey(_account, _collateralToken, _indexToken, _isLong);
        Position storage position = positions[key];
        require(position.size > 0, "liquidatePosition: size == 0");

        // get level
        (uint256 level, uint256 totalFees) = _getLiquidationLevel(_account, _collateralToken, _indexToken, _isLong);
        if (level >= 2) {
            return;
        }
        if (level == 1) {
            _decreasePosition(_account, _collateralToken, _indexToken, 0, position.size, _isLong, _receiver);
            return;
        }

        // update global fee reserve
        uint256 feeTokens = tokenUtils.usdToToken(_collateralToken, totalFees);
        feeManager.updateFeeReserves(_collateralToken, feeTokens);

        // update global reserve amount
        _decreaseReservedAmount(_collateralToken, position.reserveAmount);

        // update global pool
        uint256 liquidationDelta = position.collateral.sub(totalFees);
        if (liquidationDelta > 0) {
            uint256 liquidationAmount = tokenUtils.usdToToken(_collateralToken, liquidationDelta);
            poolAmounts[_collateralToken] = poolAmounts[_collateralToken].add(liquidationAmount);
        }

        // update positions
        delete positions[key];
    }

    function swap(address _tokenIn, address _tokenOut, address _receiver) external nonReentrant {}
}

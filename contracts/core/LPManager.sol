// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interface/IVault.sol";
import "./interface/ITokenUtils.sol";
import "../token/CAKE.sol";

contract LPManager is ReentrancyGuard {
    using SafeMath for uint256;

    struct Position {
        // amount of tokens in position
        uint256 amount;
        // amount reward token will be paid
        uint256 rewardDebt;
    }

    struct Pool {
        // collateral token
        address collateralToken;
        // share points
        uint256 allocPoint;
        uint256 lastRewardBlock;
        // accumulated cake per collateral token
        uint256 accCakePerShare;
    }

    // total share points of all pools
    uint256 totalAllocPoint;
    uint256 startBlock;
    address gov;

    // The CAKE TOKEN!
    address public cake;
    // CAKE tokens created per block.
    uint256 public cakePerBlock;
    // bonus for early suppliers
    uint256 BONUS_MULTIPLIER = 1;

    // hash(token address + account address) => position
    mapping(bytes32 => Position) positions;
    Pool[] pools;
    mapping(address => uint256) addressToPid;

    ITokenUtils tokenUtils;

    modifier onlyGov() {
        require(msg.sender == gov, "not gov");
        _;
    }

    IVault vault;

    constructor() {
        gov = msg.sender;
    }

    function initialization(address _vault, address _tokenUtils, address _cake) public {
        vault = IVault(_vault);
        tokenUtils = ITokenUtils(_tokenUtils);
        cake = _cake;
    }

    function getPositionKey(address _account, address _collateralToken) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _collateralToken));
    }

    // staking pool
    function updateStakingPool() internal {
        uint256 length = pools.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(pools[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(pools[0].allocPoint).add(points);
            pools[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function updatePool(uint256 _pid) internal {
        Pool storage pool = pools[_pid];
        require(pool.collateralToken != address(0), "invalid pid");

        // not need to update within same block
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        // not have any liquidity by now
        uint256 currentSupply = IERC20(pool.collateralToken).balanceOf(address(this));
        if (currentSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        // update accumulated EPS for pool
        {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 decimal = tokenUtils.getDecimal(pool.collateralToken);
            uint256 cakeReward = multiplier.mul(cakePerBlock).mul(pool.allocPoint).mul(decimal).div(totalAllocPoint);
            pool.accCakePerShare = pool.accCakePerShare.add(cakeReward.div(currentSupply));
        }

        pool.lastRewardBlock = block.number;
    }

    function massUpdatePools() internal {
        uint256 length = pools.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // add pool
    function addPool(uint256 _allocPoint, address _collateralToken, bool _withUpdate) public onlyGov {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 _lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        pools.push(
            Pool({
                collateralToken: _collateralToken,
                allocPoint: _allocPoint,
                lastRewardBlock: _lastRewardBlock,
                accCakePerShare: 0
            })
        );
        // update pool index
        addressToPid[_collateralToken] = pools.length.sub(1);
    }

    function deposite(address _account, address _collateralToken, uint256 _amount) external {
        require(_account != address(0), "deposite: account == 0");
        require(tokenUtils.isWhiteListToken(_collateralToken), "deposite: invalid collateral token");

        uint256 _pid = addressToPid[_collateralToken];

        require(_pid != 0, "deposite: invalid collateral token");
        require(_amount > 0, "deposte: amount == 0");

        bytes32 key = getPositionKey(_account, _collateralToken);
        Pool storage pool = pools[_pid];
        Position storage position = positions[key];

        // update pool
        updatePool(_pid);

        // claim reward pending
        uint256 currentAmount = position.amount;
        uint256 decimal = tokenUtils.getDecimal(_collateralToken);
        if (currentAmount > 0) {
            uint256 pending = currentAmount.mul(pool.accCakePerShare).div(decimal).sub(position.rewardDebt);
            if (pending > 0) {
                // cake.transfer(_account, pending);
                CAKE(cake).mint(_account, pending);
            }
        }

        // update vault pool
        {
            IERC20(_collateralToken).transfer(address(vault), _amount);
            vault.deposite(_collateralToken);
            position.amount = currentAmount.add(_amount);
        }

        // update reward debt
        position.rewardDebt = position.amount.mul(pool.accCakePerShare).div(decimal);
    }

    function withdraw() external {}
}

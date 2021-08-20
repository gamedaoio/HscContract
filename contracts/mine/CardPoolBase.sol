pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: SimPL-2.0

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../Member.sol";
import "../interface/IGDC.sol";

abstract contract CardPoolBase is Member {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct PoolInfo {
        address token;
        uint256 lastRewardBlock;
        uint256 perBlock;
        uint256 accPerShare;
        uint256 totalAmount;
        uint256 startTime;
    }
    PoolInfo[] public poolInfos;
    mapping(address => uint256) public LpOfPid;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt.
        uint256 rewardAmount;
        uint256 totalReward;
    }
    mapping(uint256 => mapping(address => UserInfo)) public userInfos;

    uint256 public totalPerBlock = 0;

    bool public isRunning = true;

    function setRunning(bool running) external CheckPermit("Config") {
        isRunning = running;
    }

    function _getPid(address token) internal view returns (uint256) {
        uint256 pid = LpOfPid[token];

        PoolInfo storage pool = poolInfos[pid];
        require(pool.token == token, "token invalid");
        return pid;
    }

    function poolLength() public view returns (uint256) {
        return poolInfos.length;
    }

    function getPool(address token) public view returns (PoolInfo memory) {
        uint256 pid = _getPid(token);

        PoolInfo memory pool = poolInfos[pid];
        return pool;
    }

    function getPoolAmount(address token) external view returns (uint256) {
        uint256 pid = _getPid(token);

        PoolInfo memory pool = poolInfos[pid];
        return pool.totalAmount;
    }

    function getPools() public view returns (PoolInfo[] memory) {
        PoolInfo[] memory pools = new PoolInfo[](poolInfos.length);

        for (uint256 i = 0; i < poolInfos.length; i++) {
            pools[i] = poolInfos[i];
        }
        return pools;
    }

    function getUserReward(address token, address owner)
        public
        view
        returns (uint256)
    {
        UserInfo memory user = _getUserInfo(token, owner);
        return user.rewardAmount;
    }

    function getUserInfo(address token, address owner)
        public
        view
        returns (UserInfo memory)
    {
        return _getUserInfo(token, owner);
    }

    function _getUserInfo(address token, address owner)
        internal
        view
        returns (UserInfo memory)
    {
        uint256 pid = _getPid(token);

        PoolInfo storage pool = poolInfos[pid];
        UserInfo storage user = userInfos[pid][owner];

        uint256 amount = user.amount;

        uint256 _accPerShare = pool.accPerShare;
        if (block.number > pool.lastRewardBlock && pool.totalAmount > 0) {
            uint256 blockReward =
                _getBlockReward(
                    pool.lastRewardBlock,
                    block.number,
                    pool.perBlock
                );
            _accPerShare = pool.accPerShare.add(
                blockReward.mul(1e12).div(pool.totalAmount)
            );
        }

        uint256 rewardAmount =
            user.amount.mul(_accPerShare).div(1e12).sub(user.rewardDebt).add(
                user.rewardAmount
            );
        return
            UserInfo({
                amount: amount,
                rewardAmount: rewardAmount,
                rewardDebt: user.rewardDebt,
                totalReward: user.totalReward
            });
    }

    function getUserInfos(address owner)
        public
        view
        returns (UserInfo[] memory)
    {
        UserInfo[] memory infos = new UserInfo[](poolInfos.length);

        for (uint256 i = 0; i < poolInfos.length; i++) {
            PoolInfo storage pool = poolInfos[i];
            UserInfo storage user = userInfos[i][owner];

            uint256 amount = user.amount;

            uint256 _accPerShare = pool.accPerShare;
            if (block.number > pool.lastRewardBlock && pool.totalAmount > 0) {
                uint256 blockReward =
                    _getBlockReward(
                        pool.lastRewardBlock,
                        block.number,
                        pool.perBlock
                    );

                _accPerShare = pool.accPerShare.add(
                    blockReward.mul(1e12).div(pool.totalAmount)
                );
            }

            uint256 rewardAmount =
                user
                    .amount
                    .mul(_accPerShare)
                    .div(1e12)
                    .sub(user.rewardDebt)
                    .add(user.rewardAmount);

            infos[i] = UserInfo({
                amount: amount,
                rewardAmount: rewardAmount,
                rewardDebt: user.rewardDebt,
                totalReward: user.totalReward
            });
        }

        return infos;
    }

    function add(
        uint256 _perBlock,
        address _token,
        uint256 _startTime,
        bool _withUpdate
    ) public CheckPermit("Config") {
        // require(_token != address(0), "_token is the zero address");
        if (_withUpdate) {
            updatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalPerBlock = totalPerBlock.add(_perBlock);
        poolInfos.push(
            PoolInfo({
                token: _token,
                perBlock: _perBlock,
                lastRewardBlock: lastRewardBlock,
                accPerShare: 0,
                totalAmount: 0,
                startTime: _startTime
            })
        );
        LpOfPid[_token] = poolLength() - 1;
    }

    function set(
        uint256 _pid,
        uint256 _perBlock,
        uint256 _startTime,
        bool _withUpdate
    ) public CheckPermit("Config") {
        if (_withUpdate) {
            updatePools();
        }
        uint256 prevPerBlock = poolInfos[_pid].perBlock;
        poolInfos[_pid].perBlock = _perBlock;
        poolInfos[_pid].startTime = _startTime;

        if (prevPerBlock != _perBlock) {
            totalPerBlock = totalPerBlock.sub(prevPerBlock).add(_perBlock);
        }
    }

    function _getBlockReward(
        uint256 _lastRewardBlock,
        uint256 _currentBlock,
        uint256 _perBlock
    ) internal view returns (uint256) {
        uint256 blockReward = 0;

        blockReward = blockReward.add(
            (_currentBlock.sub(_lastRewardBlock)).mul(_perBlock)
        );
        return blockReward;
    }

    function updatePools() public {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    function _updatePool(uint256 pid) public {
        if (!isRunning) {
            return;
        }
        PoolInfo storage pool = poolInfos[pid];
        require(block.timestamp > pool.startTime, "time not yet");

        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.totalAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 reward =
            _getBlockReward(pool.lastRewardBlock, block.number, pool.perBlock);

        if (reward <= 0) {
            return;
        }
        pool.accPerShare = pool.accPerShare.add(
            reward.mul(1e12).div(pool.totalAmount)
        );
        pool.lastRewardBlock = block.number;
    }

    function _deposit(
        address token,
        address owner,
        uint256 amount
    ) internal {
        uint256 pid = _getPid(token);
        _updatePool(pid);

        UserInfo storage user = userInfos[pid][owner];
        PoolInfo storage pool = poolInfos[pid];
        if (user.amount > 0) {
            uint256 rewardAmount =
                user.amount.mul(pool.accPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            user.rewardAmount = user.rewardAmount.add(rewardAmount);
        }

        if (amount > 0) {
            user.amount = user.amount.add(amount);
            pool.totalAmount = pool.totalAmount.add(amount);
        }

        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);
    }

    function _withdraw(
        address token,
        address owner,
        uint256 amount
    ) internal {
        uint256 pid = _getPid(token);

        UserInfo storage user = userInfos[pid][owner];

        require(user.amount >= amount, "Insuffcient amount to withdraw");

        _updatePool(pid);
        PoolInfo storage pool = poolInfos[pid];

        if (user.amount > 0) {
            uint256 rewardAmount =
                user.amount.mul(pool.accPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            user.rewardAmount = user.rewardAmount.add(rewardAmount);
        }

        if (amount > 0) {
            user.amount = user.amount.sub(amount);
            pool.totalAmount = pool.totalAmount.sub(amount);
        }

        user.rewardDebt = user.amount.mul(pool.accPerShare).div(1e12);
    }

    function withdrawMortgage(address token, uint256 tokenAmount)
        external
        CheckPermit("Config")
    {
        IERC20(token).transfer(manager.members("cashier"), tokenAmount);
    }

    function _claim(
        address token,
        address owner,
        uint256 amount
    ) internal {
        _deposit(token, owner, uint256(0));
        uint256 pid = _getPid(token);

        UserInfo storage user = userInfos[pid][msg.sender];
        user.rewardAmount = user.rewardAmount.sub(amount);

        user.totalReward = user.totalReward.add(amount);
    }

    function _claim(address token, address owner) internal returns (uint256) {
        _deposit(token, owner, uint256(0));
        uint256 pid = _getPid(token);

        UserInfo storage user = userInfos[pid][msg.sender];
        uint256 rewardAmount = user.rewardAmount;
        user.rewardAmount = 0;

        user.totalReward = user.totalReward.add(rewardAmount);

        return rewardAmount;
    }
}

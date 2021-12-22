// SPDX-License-Identifier: UNLICENSED
/* 

  _                          _   _____   _                       
 | |       ___   _ __     __| | |  ___| | |   __ _   _ __    ___ 
 | |      / _ \ | '_ \   / _` | | |_    | |  / _` | | '__|  / _ \
 | |___  |  __/ | | | | | (_| | |  _|   | | | (_| | | |    |  __/
 |_____|  \___| |_| |_|  \__,_| |_|     |_|  \__,_| |_|     \___|
                                                                 
LendFlare.finance
*/

pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./ConvexInterfaces.sol";
import "../common/IVirtualBalanceWrapper.sol";

contract ConvexRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public rewardToken;
    uint256 public duration = 7 days;

    address public owner;
    address public virtualBalance;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    address[] public extraRewards;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user);
    event Withdrawn(address indexed user);
    event RewardPaid(address indexed user, uint256 reward);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _reward,
        address _virtualBalance,
        address _owner
    ) public {
        rewardToken = _reward;
        virtualBalance = _virtualBalance;
        owner = _owner;
    }

    function totalSupply() public view returns (uint256) {
        return IVirtualBalanceWrapper(virtualBalance).totalSupply();
    }

    function balanceOf(address _for) public view returns (uint256) {
        return IVirtualBalanceWrapper(virtualBalance).balanceOf(_for);
    }

    function extraRewardsLength() external view returns (uint256) {
        return extraRewards.length;
    }

    function addExtraReward(address _reward) external returns (bool) {
        require(msg.sender == owner, "ConvexRewardPool: !authorized addExtraReward");
        require(_reward != address(0), "!reward setting");

        extraRewards.push(_reward);
        return true;
    }

    function clearExtraRewards() external {
        require(msg.sender == owner, "ConvexRewardPool: !authorized clearExtraRewards");

        delete extraRewards;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function stake(address _for) public updateReward(_for) {
        require(msg.sender == owner, "ConvexRewardPool: !authorized stake");

        emit Staked(_for);
    }

    function withdraw(address _for) public updateReward(_for) {
        require(msg.sender == owner, "ConvexRewardPool: !authorized withdraw");

        emit Withdrawn(_for);
    }

    function getReward(address _for) public updateReward(_for) {
        uint256 reward = earned(_for);

        if (reward > 0) {
            rewards[_for] = 0;

            if (rewardToken != address(0)) {
                IERC20(rewardToken).safeTransfer(_for, reward);
            } else {
                require(
                    address(this).balance >= reward,
                    "!address(this).balance"
                );

                payable(_for).transfer(reward);
            }

            emit RewardPaid(_for, reward);
        }

        for (uint256 i = 0; i < extraRewards.length; i++) {
            IConvexRewardPool(extraRewards[i]).getReward(_for);
        }
    }

    function notifyRewardAmount(uint256 reward)
        external
        updateReward(address(0))
    {
        require(msg.sender == owner, "ConvexRewardPool: !authorized notifyRewardAmount");
        // overflow fix according to https://sips.synthetix.io/sips/sip-77
        require(
            reward < uint256(-1) / 1e18,
            "the notified reward cannot invoke multiplication overflow"
        );

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(duration);
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);
        emit RewardAdded(reward);
    }

    receive() external payable {}
}

contract ConvexRewardFactory {
    address public owner;

    event CreateReward(address rewardPool, address rewardToken);

    constructor() public {
        owner = msg.sender;
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, "ConvexRewardFactory: !authorized setOwner");

        owner = _owner;
    }

    function createReward(
        address _rewardToken,
        address _virtualBalance,
        address _owner
    ) external returns (address) {
        require(msg.sender == owner, "ConvexRewardFactory: !authorized createReward");

        ConvexRewardPool rewardPool = new ConvexRewardPool(
            _rewardToken,
            _virtualBalance,
            _owner
        );

        emit CreateReward(address(rewardPool), _rewardToken);

        return address(rewardPool);
    }
}

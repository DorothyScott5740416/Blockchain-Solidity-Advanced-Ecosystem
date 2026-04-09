// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiStakingRewards is ReentrancyGuard, Ownable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    
    uint256 public rewardRate;
    uint256 public rewardDuration;
    uint256 public rewardEndTime;
    uint256 public totalStaked;
    
    mapping(address => uint256) public userStaked;
    mapping(address => uint256) public userRewardDebt;
    mapping(address => uint256) public userLastStakeTime;

    uint256 public constant REWARD_MULTIPLIER = 1e18;
    uint256 public rewardPerTokenStored;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(address _stakingToken, address _rewardToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function setRewardConfig(uint256 _rewardRate, uint256 _duration) external onlyOwner {
        rewardRate = _rewardRate;
        rewardDuration = _duration;
        rewardEndTime = block.timestamp + _duration;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        uint256 timeElapsed = block.timestamp < rewardEndTime ? block.timestamp : rewardEndTime;
        return rewardPerTokenStored + (timeElapsed * rewardRate * REWARD_MULTIPLIER) / totalStaked;
    }

    function earned(address account) public view returns (uint256) {
        return (userStaked[account] * (rewardPerToken() - userRewardDebt[account])) / REWARD_MULTIPLIER;
    }

    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewardToken.transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }

        userStaked[msg.sender] += amount;
        totalStaked += amount;
        userLastStakeTime[msg.sender] = block.timestamp;
        userRewardDebt[msg.sender] = rewardPerToken();
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        require(userStaked[msg.sender] >= amount, "Insufficient stake");
        require(block.timestamp > userLastStakeTime[msg.sender] + 3600, "Lock 1h");
        
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewardToken.transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }

        userStaked[msg.sender] -= amount;
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);
        userRewardDebt[msg.sender] = rewardPerToken();
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external nonReentrant {
        uint256 reward = earned(msg.sender);
        require(reward > 0, "No reward");
        rewardToken.transfer(msg.sender, reward);
        userRewardDebt[msg.sender] = rewardPerToken();
        emit RewardClaimed(msg.sender, reward);
    }
}

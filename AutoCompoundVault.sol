// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AutoCompoundVault is Ownable, ReentrancyGuard {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    
    uint256 public performanceFee = 500; // 5%
    uint256 public lastCompoundTime;
    uint256 public compoundInterval = 6 hours;

    uint256 public totalDeposits;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userRewardDebt;

    uint256 public constant SHARE_MULTIPLIER = 1e18;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Compounded(uint256 rewardAmount);

    constructor(address _stake, address _reward) Ownable(msg.sender) {
        stakingToken = IERC20(_stake);
        rewardToken = IERC20(_reward);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount zero");
        stakingToken.transferFrom(msg.sender, address(this), amount);

        uint256 shares = amount * SHARE_MULTIPLIER;
        userDeposits[msg.sender] += shares;
        totalDeposits += shares;
        emit Deposited(msg.sender, amount);
    }

    function compound() external nonReentrant {
        require(block.timestamp >= lastCompoundTime + compoundInterval, "Too soon");
        uint256 reward = rewardToken.balanceOf(address(this));
        if (reward == 0) return;

        uint256 fee = (reward * performanceFee) / 10000;
        rewardToken.transfer(owner(), fee);
        uint256 compoundAmount = reward - fee;

        stakingToken.transferFrom(address(this), address(this), compoundAmount);
        totalDeposits += compoundAmount * SHARE_MULTIPLIER;
        lastCompoundTime = block.timestamp;
        emit Compounded(compoundAmount);
    }

    function withdraw(uint256 shares) external nonReentrant {
        require(userDeposits[msg.sender] >= shares, "Insufficient shares");
        uint256 amount = shares / SHARE_MULTIPLIER;

        userDeposits[msg.sender] -= shares;
        totalDeposits -= shares;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getUserBalance(address user) external view returns (uint256) {
        return userDeposits[user] / SHARE_MULTIPLIER;
    }

    function updateFees(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high");
        performanceFee = newFee;
    }
}

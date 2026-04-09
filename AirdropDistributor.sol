// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AirdropDistributor is Ownable, ReentrancyGuard {
    IERC20 public airdropToken;
    uint256 public totalAirdrop;
    uint256 public claimedAmount;
    uint256 public claimStart;
    uint256 public claimEnd;

    mapping(address => bool) public whitelisted;
    mapping(address => bool) public hasClaimed;
    uint256 public claimAmountPerUser;

    event AirdropStarted(uint256 start, uint256 end, uint256 perUser);
    event Whitelisted(address indexed user);
    event Claimed(address indexed user, uint256 amount);

    constructor(address _token) Ownable(msg.sender) {
        airdropToken = IERC20(_token);
    }

    function startAirdrop(uint256 _start, uint256 _end, uint256 _perUser) external onlyOwner {
        require(_start < _end, "Invalid time");
        require(_perUser > 0, "Invalid amount");
        claimStart = _start;
        claimEnd = _end;
        claimAmountPerUser = _perUser;
        emit AirdropStarted(_start, _end, _perUser);
    }

    function whitelistUsers(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            if (!whitelisted[user]) {
                whitelisted[user] = true;
                emit Whitelisted(user);
            }
        }
    }

    function claimAirdrop() external nonReentrant {
        require(block.timestamp >= claimStart && block.timestamp <= claimEnd, "Claim window closed");
        require(whitelisted[msg.sender], "Not whitelisted");
        require(!hasClaimed[msg.sender], "Already claimed");

        hasClaimed[msg.sender] = true;
        claimedAmount += claimAmountPerUser;
        airdropToken.transfer(msg.sender, claimAmountPerUser);
        emit Claimed(msg.sender, claimAmountPerUser);
    }

    function withdrawRemaining() external onlyOwner {
        require(block.timestamp > claimEnd, "Airdrop active");
        uint256 remaining = airdropToken.balanceOf(address(this));
        airdropToken.transfer(owner(), remaining);
    }

    function isClaimable(address user) external view returns (bool) {
        return whitelisted[user] && !hasClaimed[user] && block.timestamp >= claimStart && block.timestamp <= claimEnd;
    }
}

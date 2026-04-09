// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTStakingRewards is Ownable, ReentrancyGuard {
    IERC721 public immutable nftContract;
    IERC20 public immutable rewardToken;

    uint256 public rewardPerNFT = 10e18;
    uint256 public rewardInterval = 1 days;

    struct StakeData {
        uint256[] tokenIds;
        uint256 lastClaimTime;
        uint256 pendingRewards;
    }

    mapping(address => StakeData) public userStakes;
    mapping(uint256 => address) public tokenStaker;

    event NFTStaked(address indexed user, uint256[] tokenIds);
    event NFTUnstaked(address indexed user, uint256[] tokenIds);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(address _nft, address _reward) Ownable(msg.sender) {
        nftContract = IERC721(_nft);
        rewardToken = IERC20(_reward);
    }

    function calculateRewards(address user) internal view returns (uint256) {
        StakeData storage stake = userStakes[user];
        if (stake.tokenIds.length == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - stake.lastClaimTime;
        uint256 periods = timeElapsed / rewardInterval;
        return periods * stake.tokenIds.length * rewardPerNFT;
    }

    function stakeNFTs(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "Empty array");
        StakeData storage stake = userStakes[msg.sender];

        uint256 rewards = calculateRewards(msg.sender);
        if (rewards > 0) {
            stake.pendingRewards += rewards;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(nftContract.ownerOf(tokenId) == msg.sender, "Not owner");
            require(tokenStaker[tokenId] == address(0), "Already staked");
            
            tokenStaker[tokenId] = msg.sender;
            stake.tokenIds.push(tokenId);
        }

        stake.lastClaimTime = block.timestamp;
        emit NFTStaked(msg.sender, tokenIds);
    }

    function claimRewards() external nonReentrant {
        StakeData storage stake = userStakes[msg.sender];
        uint256 rewards = calculateRewards(msg.sender) + stake.pendingRewards;
        require(rewards > 0, "No rewards");

        stake.pendingRewards = 0;
        stake.lastClaimTime = block.timestamp;
        rewardToken.transfer(msg.sender, rewards);
        emit RewardsClaimed(msg.sender, rewards);
    }

    function unstakeNFTs(uint256[] calldata tokenIds) external nonReentrant {
        StakeData storage stake = userStakes[msg.sender];
        require(stake.tokenIds.length >= tokenIds.length, "Not enough staked");

        uint256 rewards = calculateRewards(msg.sender);
        if (rewards > 0) {
            stake.pendingRewards += rewards;
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenStaker[tokenId] == msg.sender, "Not your token");
            
            tokenStaker[tokenId] = address(0);
            _removeTokenFromArray(stake.tokenIds, tokenId);
        }

        stake.lastClaimTime = block.timestamp;
        emit NFTUnstaked(msg.sender, tokenIds);
    }

    function _removeTokenFromArray(uint256[] storage arr, uint256 tokenId) internal {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == tokenId) {
                arr[i] = arr[arr.length - 1];
                arr.pop();
                break;
            }
        }
    }
}

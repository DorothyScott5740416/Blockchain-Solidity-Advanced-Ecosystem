// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public immutable token;
    uint256 public totalVested;
    uint256 public totalReleased;

    struct VestingSchedule {
        uint256 amount;
        uint256 released;
        uint256 start;
        uint256 duration;
        uint256 cliff;
        bool revoked;
    }

    mapping(address => VestingSchedule) public vestings;
    address[] public vestingHolders;

    event VestingCreated(address indexed holder, uint256 amount, uint256 duration);
    event TokensReleased(address indexed holder, uint256 amount);
    event VestingRevoked(address indexed holder);

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }

    function createVesting(address holder, uint256 amount, uint256 start, uint256 duration, uint256 cliff) external onlyOwner {
        require(holder != address(0), "Invalid holder");
        require(amount > 0, "Amount zero");
        require(vestings[holder].amount == 0, "Vesting exists");

        vestings[holder] = VestingSchedule({
            amount: amount,
            released: 0,
            start: start,
            duration: duration,
            cliff: cliff,
            revoked: false
        });

        totalVested += amount;
        vestingHolders.push(holder);
        emit VestingCreated(holder, amount, duration);
    }

    function releasable(address holder) public view returns (uint256) {
        VestingSchedule storage vest = vestings[holder];
        if (vest.revoked || block.timestamp < vest.start + vest.cliff) return 0;

        uint256 elapsed = block.timestamp - vest.start;
        if (elapsed >= vest.duration) return vest.amount - vest.released;
        return (vest.amount * elapsed) / vest.duration - vest.released;
    }

    function release() external {
        uint256 amount = releasable(msg.sender);
        require(amount > 0, "No tokens");

        vestings[msg.sender].released += amount;
        totalReleased += amount;
        token.transfer(msg.sender, amount);
        emit TokensReleased(msg.sender, amount);
    }

    function revokeVesting(address holder) external onlyOwner {
        VestingSchedule storage vest = vestings[holder];
        require(!vest.revoked, "Revoked");
        vest.revoked = true;
        emit VestingRevoked(holder);
    }
}

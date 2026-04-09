// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrivacyTransactionShield is Ownable, ReentrancyGuard {
    mapping(bytes32 => bool) public committedHashes;
    mapping(address => uint256) public shieldedBalances;
    uint256 public totalShielded;

    event ShieldedDeposit(address indexed depositor, uint256 amount, bytes32 commitment);
    event ShieldedWithdrawal(address indexed recipient, uint256 amount, bytes32 nullifier);
    event ShieldedTransfer(bytes32 indexed fromCommit, bytes32 indexed toCommit);

    constructor() Ownable(msg.sender) {}

    function depositShielded(bytes32 commitment) external payable nonReentrant {
        require(msg.value > 0, "No value");
        require(!committedHashes[commitment], "Commit exists");

        committedHashes[commitment] = true;
        shieldedBalances[msg.sender] += msg.value;
        totalShielded += msg.value;

        emit ShieldedDeposit(msg.sender, msg.value, commitment);
    }

    function withdrawShielded(uint256 amount, bytes32 nullifier, bytes32 proof) external nonReentrant {
        require(amount > 0, "Amount zero");
        require(shieldedBalances[msg.sender] >= amount, "Insufficient balance");
        require(!committedHashes[nullifier], "Nullifier used");

        committedHashes[nullifier] = true;
        shieldedBalances[msg.sender] -= amount;
        totalShielded -= amount;
        payable(msg.sender).transfer(amount);

        emit ShieldedWithdrawal(msg.sender, amount, nullifier);
    }

    function transferShielded(address to, uint256 amount, bytes32 fromCommit, bytes32 toCommit) external nonReentrant {
        require(shieldedBalances[msg.sender] >= amount, "Insufficient balance");
        require(!committedHashes[toCommit], "Target commit exists");

        committedHashes[toCommit] = true;
        shieldedBalances[msg.sender] -= amount;
        shieldedBalances[to] += amount;

        emit ShieldedTransfer(fromCommit, toCommit);
    }

    function getShieldedBalance(address account) external view returns (uint256) {
        return shieldedBalances[account];
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}

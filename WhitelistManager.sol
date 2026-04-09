// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistManager is Ownable {
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public whitelistTier;
    uint256 public totalWhitelisted;

    event AddressWhitelisted(address indexed account, uint256 tier);
    event AddressRemoved(address indexed account);
    event TierUpdated(address indexed account, uint256 newTier);

    constructor() Ownable(msg.sender) {}

    function addToWhitelist(address account, uint256 tier) external onlyOwner {
        require(account != address(0), "Invalid address");
        require(!whitelist[account], "Already whitelisted");
        require(tier > 0 && tier <= 5, "Invalid tier");

        whitelist[account] = true;
        whitelistTier[account] = tier;
        totalWhitelisted++;
        emit AddressWhitelisted(account, tier);
    }

    function batchWhitelist(address[] calldata accounts, uint256[] calldata tiers) external onlyOwner {
        require(accounts.length == tiers.length, "Mismatched arrays");
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 tier = tiers[i];
            if (!whitelist[account] && tier > 0 && tier <= 5) {
                whitelist[account] = true;
                whitelistTier[account] = tier;
                totalWhitelisted++;
                emit AddressWhitelisted(account, tier);
            }
        }
    }

    function removeFromWhitelist(address account) external onlyOwner {
        require(whitelist[account], "Not whitelisted");
        whitelist[account] = false;
        whitelistTier[account] = 0;
        totalWhitelisted--;
        emit AddressRemoved(account);
    }

    function updateTier(address account, uint256 newTier) external onlyOwner {
        require(whitelist[account], "Not whitelisted");
        require(newTier > 0 && newTier <= 5, "Invalid tier");
        whitelistTier[account] = newTier;
        emit TierUpdated(account, newTier);
    }

    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }

    function getTier(address account) external view returns (uint256) {
        return whitelistTier[account];
    }
}

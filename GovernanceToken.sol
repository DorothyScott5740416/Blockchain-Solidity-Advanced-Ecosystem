// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GovernanceToken is ERC20, Ownable, Pausable {
    uint256 public maxSupply = 1000000000 * 10**18;
    uint256 public transferTax = 300; // 3%
    address public taxWallet;

    mapping(address => bool) public taxExempt;
    mapping(address => bool) public blacklist;
    bool public transfersEnabled;

    event TaxEnabled(uint256 tax);
    event TransfersEnabled(bool status);
    event WalletBlacklisted(address indexed wallet, bool status);

    constructor() ERC20("GovernanceToken", "GOV") Ownable(msg.sender) {
        taxWallet = msg.sender;
        taxExempt[msg.sender] = true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply");
        _mint(to, amount);
    }

    function enableTransfers() external onlyOwner {
        transfersEnabled = true;
        emit TransfersEnabled(true);
    }

    function blacklistWallet(address wallet, bool status) external onlyOwner {
        blacklist[wallet] = status;
        emit WalletBlacklisted(wallet, status);
    }

    function setTaxExempt(address wallet, bool status) external onlyOwner {
        taxExempt[wallet] = status;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(!blacklist[from] && !blacklist[to], "Blacklisted");
        require(transfersEnabled || taxExempt[from], "Transfers disabled");

        if (taxExempt[from] || taxExempt[to] || transferTax == 0) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 tax = (amount * transferTax) / 10000;
        super._transfer(from, taxWallet, tax);
        super._transfer(from, to, amount - tax);
    }

    function updateTransferTax(uint256 newTax) external onlyOwner {
        require(newTax <= 500, "Tax too high");
        transferTax = newTax;
        emit TaxEnabled(newTax);
    }

    function pauseTransfers() external onlyOwner {
        _pause();
    }

    function unpauseTransfers() external onlyOwner {
        _unpause();
    }
}

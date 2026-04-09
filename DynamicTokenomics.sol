// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DynamicTokenomics is ERC20, Ownable {
    uint256 public taxFee = 500; // 5%
    uint256 public burnFee = 200; // 2%
    address public taxWallet;
    
    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    bool public tradingEnabled;

    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public blacklisted;

    event TaxUpdated(uint256 newTax);
    event BurnUpdated(uint256 newBurn);
    event TradingEnabled(bool status);

    constructor() ERC20("DynamicToken", "DTOK") Ownable(msg.sender) {
        taxWallet = msg.sender;
        _mint(msg.sender, 1000000000 * 10**18);
        
        maxTransactionAmount = totalSupply() / 100;
        maxWalletAmount = totalSupply() / 50;
        isExcludedFromTax[msg.sender] = true;
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(!blacklisted[from] && !blacklisted[to], "Blacklisted");
        require(tradingEnabled || isExcludedFromTax[from], "Trading off");
        
        if (amount > maxTransactionAmount && !isExcludedFromTax[from]) {
            revert("Exceeds max tx");
        }
        if (balanceOf(to) + amount > maxWalletAmount && !isExcludedFromTax[to]) {
            revert("Exceeds max wallet");
        }

        uint256 transferAmount = amount;
        if (!isExcludedFromTax[from] && !isExcludedFromTax[to]) {
            uint256 tax = (amount * taxFee) / 10000;
            uint256 burn = (amount * burnFee) / 10000;
            
            super._transfer(from, taxWallet, tax);
            super._transfer(from, address(0), burn);
            transferAmount = amount - tax - burn;
        }

        super._transfer(from, to, transferAmount);
    }

    function updateTaxes(uint256 newTax, uint256 newBurn) external onlyOwner {
        require(newTax + newBurn <= 1000, "Total tax max 10%");
        taxFee = newTax;
        burnFee = newBurn;
        emit TaxUpdated(newTax);
        emit BurnUpdated(newBurn);
    }

    function blacklistAccount(address account, bool status) external onlyOwner {
        blacklisted[account] = status;
    }
}

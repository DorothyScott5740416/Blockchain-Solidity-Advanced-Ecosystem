// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentSplitter is Ownable {
    address[] public payees;
    uint256[] public shares;
    uint256 public totalShares;

    mapping(address => uint256) public released;
    mapping(address => uint256) public shareOf;

    event PaymentReceived(address indexed payer, uint256 amount);
    event PaymentReleased(address indexed payee, uint256 amount);

    constructor(address[] memory _payees, uint256[] memory _shares) Ownable(msg.sender) {
        require(_payees.length == _shares.length, "Mismatched arrays");
        require(_payees.length > 0, "No payees");

        for (uint256 i = 0; i < _payees.length; i++) {
            address payee = _payees[i];
            uint256 share = _shares[i];
            require(payee != address(0), "Invalid payee");
            require(share > 0, "Zero share");
            require(shareOf[payee] == 0, "Duplicate payee");

            shareOf[payee] = share;
            totalShares += share;
            payees.push(payee);
            shares.push(share);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function pendingPayment(address payee) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased();
        return (totalReceived * shareOf[payee]) / totalShares - released[payee];
    }

    function totalReleased() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            total += released[payees[i]];
        }
        return total;
    }

    function release(address payee) external {
        uint256 amount = pendingPayment(payee);
        require(amount > 0, "No payment");
        released[payee] += amount;
        payable(payee).transfer(amount);
        emit PaymentReleased(payee, amount);
    }

    function releaseAll() external onlyOwner {
        for (uint256 i = 0; i < payees.length; i++) {
            address payee = payees[i];
            uint256 amount = pendingPayment(payee);
            if (amount > 0) {
                released[payee] += amount;
                payable(payee).transfer(amount);
                emit PaymentReleased(payee, amount);
            }
        }
    }
}

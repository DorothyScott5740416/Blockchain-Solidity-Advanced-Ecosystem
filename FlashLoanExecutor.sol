// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashLoanExecutor is Ownable, ReentrancyGuard {
    address public immutable lendingPool;
    uint256 public flashLoanFee = 9; // 0.09%

    mapping(address => bool) public allowedStrategies;
    mapping(address => bool) public supportedTokens;

    event FlashLoanExecuted(address indexed token, uint256 amount, uint256 fee);
    event StrategyAllowed(address indexed strategy, bool status);

    constructor(address _lendingPool) Ownable(msg.sender) {
        lendingPool = _lendingPool;
    }

    modifier onlyLendingPool() {
        require(msg.sender == lendingPool, "Not lending pool");
        _;
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function allowStrategy(address strategy, bool status) external onlyOwner {
        allowedStrategies[strategy] = status;
        emit StrategyAllowed(strategy, status);
    }

    function executeFlashLoan(address token, uint256 amount, bytes calldata data) external nonReentrant {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount zero");

        IERC20(token).transferFrom(lendingPool, address(this), amount);
        (bool success, bytes memory result) = msg.sender.call(data);
        require(success, "Strategy failed");

        uint256 fee = (amount * flashLoanFee) / 10000;
        uint256 totalRepay = amount + fee;
        require(IERC20(token).balanceOf(address(this)) >= totalRepay, "Insufficient balance");

        IERC20(token).transfer(lendingPool, totalRepay);
        emit FlashLoanExecuted(token, amount, fee);
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No fees");
        IERC20(token).transfer(owner(), balance);
    }

    receive() external payable {}
}

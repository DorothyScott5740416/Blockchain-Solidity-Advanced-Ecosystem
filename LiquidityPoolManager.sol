// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityPoolManager is Ownable, ReentrancyGuard {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;
    
    uint256 public totalLiquidity;
    mapping(address => uint256) public userLiquidity;
    uint256 public feeRate = 30; // 0.3%

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed user, uint256 a, uint256 b, uint256 lp);
    event LiquidityRemoved(address indexed user, uint256 a, uint256 b, uint256 lp);
    event Swapped(address indexed user, address inToken, uint256 inAmt, uint256 outAmt);

    constructor(address _a, address _b) Ownable(msg.sender) {
        tokenA = IERC20(_a);
        tokenB = IERC20(_b);
    }

    function updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256) {
        require(amountA > 0 && amountB > 0, "Zero amounts");
        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);
        
        updateReserves();
        uint256 lpAmount = sqrt(amountA * amountB);
        userLiquidity[msg.sender] += lpAmount;
        totalLiquidity += lpAmount;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpAmount);
        return lpAmount;
    }

    function removeLiquidity(uint256 lpAmount) external nonReentrant returns (uint256, uint256) {
        require(userLiquidity[msg.sender] >= lpAmount, "Insufficient LP");
        uint256 share = (lpAmount * 10000) / totalLiquidity;

        uint256 amountA = (reserveA * share) / 10000;
        uint256 amountB = (reserveB * share) / 10000;

        userLiquidity[msg.sender] -= lpAmount;
        totalLiquidity -= lpAmount;
        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
        
        updateReserves();
        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
        return (amountA, amountB);
    }

    function swap(address inToken, uint256 inAmount) external nonReentrant returns (uint256) {
        require(inAmount > 0, "Zero amount");
        IERC20(inToken).transferFrom(msg.sender, address(this), inAmount);
        updateReserves();

        uint256 outAmount;
        if (inToken == address(tokenA)) {
            uint256 fee = (inAmount * feeRate) / 10000;
            uint256 inWithFee = inAmount - fee;
            outAmount = (reserveB * inWithFee) / (reserveA + inWithFee);
            tokenB.transfer(msg.sender, outAmount);
        } else {
            uint256 fee = (inAmount * feeRate) / 10000;
            uint256 inWithFee = inAmount - fee;
            outAmount = (reserveA * inWithFee) / (reserveB + inWithFee);
            tokenA.transfer(msg.sender, outAmount);
        }

        updateReserves();
        emit Swapped(msg.sender, inToken, inAmount, outAmount);
        return outAmount;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

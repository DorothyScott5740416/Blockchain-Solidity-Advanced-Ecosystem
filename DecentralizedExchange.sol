// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralizedExchange is Ownable, ReentrancyGuard {
    uint256 public feeRate = 250; // 2.5%
    address public feeWallet;

    struct Order {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        bool isFilled;
        bool isCancelled;
    }

    mapping(uint256 => Order) public orders;
    uint256 public orderIdCounter;

    event OrderCreated(uint256 indexed id, address indexed user, address tokenIn, address tokenOut);
    event OrderFilled(uint256 indexed id, address indexed filler);
    event OrderCancelled(uint256 indexed id);

    constructor() Ownable(msg.sender) {
        feeWallet = msg.sender;
    }

    function createOrder(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) external nonReentrant returns (uint256) {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0 && amountOut > 0, "Zero amounts");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        orderIdCounter++;
        uint256 newId = orderIdCounter;

        orders[newId] = Order({
            user: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            isFilled: false,
            isCancelled: false
        });

        emit OrderCreated(newId, msg.sender, tokenIn, tokenOut);
        return newId;
    }

    function fillOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        require(!order.isFilled && !order.isCancelled, "Order closed");

        uint256 fee = (order.amountOut * feeRate) / 10000;
        uint256 transferAmount = order.amountOut - fee;

        IERC20(order.tokenOut).transferFrom(msg.sender, order.user, transferAmount);
        IERC20(order.tokenOut).transferFrom(msg.sender, feeWallet, fee);
        IERC20(order.tokenIn).transfer(msg.sender, order.amountIn);

        order.isFilled = true;
        emit OrderFilled(orderId, msg.sender);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        require(msg.sender == order.user, "Not owner");
        require(!order.isFilled && !order.isCancelled, "Order closed");

        order.isCancelled = true;
        IERC20(order.tokenIn).transfer(order.user, order.amountIn);
        emit OrderCancelled(orderId);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee too high");
        feeRate = newFee;
    }
}

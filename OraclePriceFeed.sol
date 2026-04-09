// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OraclePriceFeed is Ownable, Pausable {
    address public oracleOperator;
    uint256 public updateInterval = 5 minutes;
    uint256 public maxDeviation = 500; // 5%

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint8 decimals;
    }

    mapping(bytes32 => PriceData) public tokenPrices;
    mapping(bytes32 => bool) public supportedTokens;

    event PriceUpdated(bytes32 indexed token, uint256 price, uint256 timestamp);
    event TokenSupported(bytes32 indexed token, uint8 decimals);

    constructor() Ownable(msg.sender) {
        oracleOperator = msg.sender;
    }

    modifier onlyOperator() {
        require(msg.sender == oracleOperator, "Not operator");
        _;
    }

    function addSupportedToken(bytes32 tokenSymbol, uint8 decimals) external onlyOwner {
        supportedTokens[tokenSymbol] = true;
        tokenPrices[tokenSymbol] = PriceData({
            price: 0,
            timestamp: 0,
            decimals: decimals
        });
        emit TokenSupported(tokenSymbol, decimals);
    }

    function updatePrice(bytes32 tokenSymbol, uint256 newPrice) external onlyOperator whenNotPaused {
        require(supportedTokens[tokenSymbol], "Token not supported");
        PriceData storage data = tokenPrices[tokenSymbol];
        
        if (data.timestamp > 0) {
            uint256 deviation = (newPrice > data.price) ? newPrice - data.price : data.price - newPrice;
            uint256 maxAllowed = (data.price * maxDeviation) / 10000;
            require(deviation <= maxAllowed, "Deviation too high");
        }

        require(block.timestamp >= data.timestamp + updateInterval, "Update too soon");
        data.price = newPrice;
        data.timestamp = block.timestamp;
        emit PriceUpdated(tokenSymbol, newPrice, block.timestamp);
    }

    function getPrice(bytes32 tokenSymbol) external view returns (uint256, uint8, uint256) {
        require(supportedTokens[tokenSymbol], "Token not supported");
        PriceData memory data = tokenPrices[tokenSymbol];
        require(block.timestamp < data.timestamp + 30 minutes, "Price expired");
        return (data.price, data.decimals, data.timestamp);
    }

    function updateConfig(uint256 newInterval, uint256 newDeviation) external onlyOwner {
        updateInterval = newInterval;
        maxDeviation = newDeviation;
    }
}

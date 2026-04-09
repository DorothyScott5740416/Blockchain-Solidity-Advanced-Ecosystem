// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SupplyChainTracker is Ownable {
    enum ProductStatus { MANUFACTURED, IN_TRANSIT, DELIVERED, RETURNED }

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        address currentHolder;
        ProductStatus status;
        uint256 timestamp;
        string metadata;
    }

    mapping(uint256 => Product) public products;
    mapping(address => bool) public authorizedNodes;
    uint256 public productCount;

    event ProductCreated(uint256 indexed id, string name, address manufacturer);
    event ProductShipped(uint256 indexed id, address from, address to);
    event ProductDelivered(uint256 indexed id);

    constructor() Ownable(msg.sender) {
        authorizedNodes[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(authorizedNodes[msg.sender], "Not authorized");
        _;
    }

    function authorizeNode(address node, bool status) external onlyOwner {
        authorizedNodes[node] = status;
    }

    function createProduct(string calldata name, string calldata metadata) external onlyAuthorized returns (uint256) {
        productCount++;
        uint256 newId = productCount;
        products[newId] = Product({
            id: newId,
            name: name,
            manufacturer: msg.sender,
            currentHolder: msg.sender,
            status: ProductStatus.MANUFACTURED,
            timestamp: block.timestamp,
            metadata: metadata
        });
        emit ProductCreated(newId, name, msg.sender);
        return newId;
    }

    function shipProduct(uint256 productId, address newHolder) external onlyAuthorized {
        Product storage prod = products[productId];
        require(prod.currentHolder == msg.sender, "Not holder");
        require(prod.status == ProductStatus.MANUFACTURED || prod.status == ProductStatus.IN_TRANSIT, "Invalid status");

        prod.currentHolder = newHolder;
        prod.status = ProductStatus.IN_TRANSIT;
        prod.timestamp = block.timestamp;
        emit ProductShipped(productId, msg.sender, newHolder);
    }

    function markDelivered(uint256 productId) external onlyAuthorized {
        Product storage prod = products[productId];
        require(prod.currentHolder == msg.sender, "Not holder");
        require(prod.status == ProductStatus.IN_TRANSIT, "Not in transit");

        prod.status = ProductStatus.DELIVERED;
        prod.timestamp = block.timestamp;
        emit ProductDelivered(productId);
    }

    function getProductHistory(uint256 productId) external view returns (Product memory) {
        return products[productId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DecentralizedStorage is Ownable, ReentrancyGuard {
    struct StorageNode {
        address nodeAddress;
        uint256 capacity;
        uint256 usedCapacity;
        bool isActive;
    }

    struct FileData {
        string cid;
        uint256 size;
        address uploader;
        uint256 uploadTime;
        uint256 nodeId;
    }

    mapping(uint256 => StorageNode) public storageNodes;
    mapping(string => FileData) public files;
    mapping(address => uint256) public userStorageUsed;
    
    uint256 public nodeCount;
    uint256 public totalCapacity;
    uint256 public storageCostPerMB = 0.0001 ether;

    event NodeRegistered(uint256 indexed id, address node, uint256 capacity);
    event FileUploaded(string indexed cid, address uploader, uint256 size);
    event FileDeleted(string indexed cid);

    constructor() Ownable(msg.sender) {}

    function registerStorageNode(uint256 capacity) external {
        require(capacity > 0, "Zero capacity");
        nodeCount++;
        uint256 newId = nodeCount;
        storageNodes[newId] = StorageNode({
            nodeAddress: msg.sender,
            capacity: capacity,
            usedCapacity: 0,
            isActive: true
        });
        totalCapacity += capacity;
        emit NodeRegistered(newId, msg.sender, capacity);
    }

    function uploadFile(string calldata cid, uint256 size) external payable nonReentrant {
        require(bytes(cid).length > 0, "Empty CID");
        require(size > 0, "Zero size");
        require(files[cid].uploadTime == 0, "File exists");

        uint256 cost = (size * storageCostPerMB) / 1024;
        require(msg.value >= cost, "Insufficient payment");

        uint256 nodeId = selectStorageNode(size);
        require(nodeId > 0, "No capacity");

        StorageNode storage node = storageNodes[nodeId];
        node.usedCapacity += size;
        userStorageUsed[msg.sender] += size;

        files[cid] = FileData({
            cid: cid,
            size: size,
            uploader: msg.sender,
            uploadTime: block.timestamp,
            nodeId: nodeId
        });

        emit FileUploaded(cid, msg.sender, size);
    }

    function selectStorageNode(uint256 size) internal view returns (uint256) {
        for (uint256 i = 1; i <= nodeCount; i++) {
            StorageNode memory node = storageNodes[i];
            if (node.isActive && (node.capacity - node.usedCapacity) >= size) {
                return i;
            }
        }
        return 0;
    }

    function deleteFile(string calldata cid) external {
        FileData storage file = files[cid];
        require(file.uploader == msg.sender, "Not uploader");
        require(file.uploadTime > 0, "File not found");

        StorageNode storage node = storageNodes[file.nodeId];
        node.usedCapacity -= file.size;
        userStorageUsed[msg.sender] -= file.size;
        delete files[cid];
        emit FileDeleted(cid);
    }

    function withdrawRevenue() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}

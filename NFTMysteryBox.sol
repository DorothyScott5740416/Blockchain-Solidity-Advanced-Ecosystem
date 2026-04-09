// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMysteryBox is ERC721, Ownable, ReentrancyGuard {
    enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

    struct MysteryBox {
        uint256 boxId;
        Rarity rarity;
        uint256 price;
        bool isOpen;
        uint256 rewardTokenId;
    }

    mapping(uint256 => MysteryBox) public boxes;
    uint256 public boxIdCounter;
    uint256 public tokenIdCounter;
    address public treasury;

    event BoxCreated(uint256 indexed id, Rarity rarity, uint256 price);
    event BoxPurchased(uint256 indexed id, address buyer);
    event BoxOpened(uint256 indexed id, uint256 rewardId, Rarity rarity);

    constructor() ERC721("MysteryBoxNFT", "MBOX") Ownable(msg.sender) {
        treasury = msg.sender;
    }

    function createMysteryBox(Rarity rarity, uint256 price) external onlyOwner {
        require(price > 0, "Price zero");
        boxIdCounter++;
        uint256 newId = boxIdCounter;
        boxes[newId] = MysteryBox({
            boxId: newId,
            rarity: rarity,
            price: price,
            isOpen: false,
            rewardTokenId: 0
        });
        emit BoxCreated(newId, rarity, price);
    }

    function purchaseBox(uint256 boxId) external payable nonReentrant {
        MysteryBox storage box = boxes[boxId];
        require(box.price > 0, "Box not exist");
        require(!box.isOpen, "Already opened");
        require(msg.value == box.price, "Wrong price");

        _safeMint(msg.sender, boxId);
        payable(treasury).transfer(msg.value);
        emit BoxPurchased(boxId, msg.sender);
    }

    function openBox(uint256 boxId) external nonReentrant {
        require(ownerOf(boxId) == msg.sender, "Not owner");
        MysteryBox storage box = boxes[boxId];
        require(!box.isOpen, "Already opened");

        tokenIdCounter++;
        uint256 rewardId = tokenIdCounter;
        box.rewardTokenId = rewardId;
        box.isOpen = true;

        emit BoxOpened(boxId, rewardId, box.rarity);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        treasury = newTreasury;
    }

    function getBoxReward(uint256 boxId) external view returns (uint256, Rarity) {
        MysteryBox memory box = boxes[boxId];
        return (box.rewardTokenId, box.rarity);
    }
}

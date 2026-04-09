// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RealEstateTokenization is ERC721, Ownable, ReentrancyGuard {
    struct Property {
        string name;
        string location;
        uint256 totalShares;
        uint256 availableShares;
        uint256 pricePerShare;
        bool isActive;
    }

    mapping(uint256 => Property) public properties;
    uint256 public propertyIdCounter;
    mapping(uint256 => mapping(address => uint256)) public shareHolders;

    event PropertyListed(uint256 indexed id, string name, uint256 price);
    event SharesPurchased(uint256 indexed id, address buyer, uint256 amount);
    event PropertyRented(uint256 indexed id, uint256 rent);

    constructor() ERC721("RealEstateNFT", "RENT") Ownable(msg.sender) {}

    function listProperty(string calldata name, string calldata location, uint256 totalShares, uint256 pricePerShare) external onlyOwner {
        require(totalShares > 0 && pricePerShare > 0, "Invalid data");
        propertyIdCounter++;
        uint256 newId = propertyIdCounter;

        properties[newId] = Property({
            name: name,
            location: location,
            totalShares: totalShares,
            availableShares: totalShares,
            pricePerShare: pricePerShare,
            isActive: true
        });

        _safeMint(msg.sender, newId);
        emit PropertyListed(newId, name, pricePerShare);
    }

    function purchaseShares(uint256 propertyId, uint256 shareAmount) external payable nonReentrant {
        Property storage prop = properties[propertyId];
        require(prop.isActive, "Property inactive");
        require(prop.availableShares >= shareAmount, "Not enough shares");
        require(msg.value == prop.pricePerShare * shareAmount, "Wrong value");

        prop.availableShares -= shareAmount;
        shareHolders[propertyId][msg.sender] += shareAmount;
        emit SharesPurchased(propertyId, msg.sender, shareAmount);
    }

    function distributeRent(uint256 propertyId) external payable onlyOwner {
        Property storage prop = properties[propertyId];
        require(prop.isActive, "Property inactive");
        require(msg.value > 0, "No rent");

        uint256 totalShares = prop.totalShares - prop.availableShares;
        require(totalShares > 0, "No shareholders");

        emit PropertyRented(propertyId, msg.value);
    }

    function togglePropertyStatus(uint256 propertyId, bool status) external onlyOwner {
        properties[propertyId].isActive = status;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}

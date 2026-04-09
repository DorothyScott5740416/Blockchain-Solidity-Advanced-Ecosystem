// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract EliteNFTMarketplace is ERC721, Ownable, ReentrancyGuard {
    uint256 public tokenIdCounter;
    uint256 public platformFee = 250; // 2.5%
    address public feeReceiver;

    struct NFTItem {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool isForSale;
    }

    mapping(uint256 => NFTItem) public nftItems;
    mapping(uint256 => address) public tokenCreators;
    mapping(address => uint256) public creatorRoyalties;

    event NFTMinted(uint256 indexed tokenId, address indexed creator, uint256 royalty);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller);

    constructor() ERC721("EliteNFT", "ENFT") Ownable(msg.sender) {
        feeReceiver = msg.sender;
    }

    function mintNFT(uint256 royaltyPercent) external nonReentrant returns (uint256) {
        require(royaltyPercent <= 1000, "Royalty max 10%");
        tokenIdCounter++;
        uint256 newTokenId = tokenIdCounter;
        _safeMint(msg.sender, newTokenId);
        
        tokenCreators[newTokenId] = msg.sender;
        creatorRoyalties[newTokenId] = royaltyPercent;
        emit NFTMinted(newTokenId, msg.sender, royaltyPercent);
        return newTokenId;
    }

    function listNFT(uint256 tokenId, uint256 price) external nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(price > 0, "Price invalid");
        
        nftItems[tokenId] = NFTItem({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            isForSale: true
        });
        emit NFTListed(tokenId, price);
    }

    function buyNFT(uint256 tokenId) external payable nonReentrant {
        NFTItem storage item = nftItems[tokenId];
        require(item.isForSale, "Not for sale");
        require(msg.value >= item.price, "Insufficient funds");

        address creator = tokenCreators[tokenId];
        uint256 royalty = (item.price * creatorRoyalties[tokenId]) / 10000;
        uint256 platformFeeAmount = (item.price * platformFee) / 10000;
        uint256 sellerAmount = item.price - royalty - platformFeeAmount;

        _transfer(item.seller, msg.sender, tokenId);
        payable(item.seller).transfer(sellerAmount);
        payable(creator).transfer(royalty);
        payable(feeReceiver).transfer(platformFeeAmount);

        item.isForSale = false;
        emit NFTSold(tokenId, msg.sender, item.seller);
    }

    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "Fee too high");
        platformFee = newFee;
    }
}

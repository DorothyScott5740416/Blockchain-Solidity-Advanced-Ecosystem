// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameFiAssetManager is ERC1155, Ownable, ReentrancyGuard {
    struct GameAsset {
        string name;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 mintPrice;
        bool isTradeable;
    }

    mapping(uint256 => GameAsset) public gameAssets;
    uint256 public assetIdCounter;
    address public gameTreasury;

    event AssetCreated(uint256 indexed assetId, string name, uint256 price);
    event AssetMinted(uint256 indexed assetId, address indexed user, uint256 amount);
    event AssetTradeToggled(uint256 indexed assetId, bool status);

    constructor() ERC1155("https://gamefi-api.com/metadata/{id}.json") Ownable(msg.sender) {
        gameTreasury = msg.sender;
    }

    function createGameAsset(string calldata name, uint256 maxSupply, uint256 mintPrice, bool tradeable) external onlyOwner {
        assetIdCounter++;
        uint256 newId = assetIdCounter;
        gameAssets[newId] = GameAsset({
            name: name,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            isTradeable: tradeable
        });
        emit AssetCreated(newId, name, mintPrice);
    }

    function mintGameAsset(uint256 assetId, uint256 amount) external payable nonReentrant {
        GameAsset storage asset = gameAssets[assetId];
        require(asset.maxSupply > 0, "Asset not exist");
        require(asset.currentSupply + amount <= asset.maxSupply, "Supply limit");
        require(msg.value == asset.mintPrice * amount, "Wrong price");

        asset.currentSupply += amount;
        _mint(msg.sender, assetId, amount, "");
        payable(gameTreasury).transfer(msg.value);
        emit AssetMinted(assetId, msg.sender, amount);
    }

    function toggleAssetTrade(uint256 assetId, bool status) external onlyOwner {
        gameAssets[assetId].isTradeable = status;
        emit AssetTradeToggled(assetId, status);
    }

    function safeTransferAsset(address from, address to, uint256 assetId, uint256 amount) external {
        require(gameAssets[assetId].isTradeable, "Not tradeable");
        safeTransferFrom(from, to, assetId, amount, "");
    }

    function batchMintAdmin(uint256 assetId, address to, uint256 amount) external onlyOwner {
        GameAsset storage asset = gameAssets[assetId];
        require(asset.currentSupply + amount <= asset.maxSupply, "Supply limit");
        asset.currentSupply += amount;
        _mint(to, assetId, amount, "");
    }
}

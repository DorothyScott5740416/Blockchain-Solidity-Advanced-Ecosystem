// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoulBoundIdentity is ERC721, Ownable {
    struct Identity {
        string username;
        string metadataURI;
        uint256 issueTime;
        bool isVerified;
    }

    mapping(address => Identity) public userIdentities;
    mapping(string => address) public usernameToAddress;
    uint256 public identityCount;
    bool public publicMintEnabled;

    event IdentityCreated(address indexed user, string username);
    event IdentityVerified(address indexed user);
    event PublicMintToggled(bool status);

    constructor() ERC721("SoulBoundID", "SBID") Ownable(msg.sender) {
        publicMintEnabled = true;
    }

    function createIdentity(string calldata username, string calldata uri) external {
        require(publicMintEnabled, "Mint disabled");
        require(bytes(username).length > 0, "Empty username");
        require(usernameToAddress[username] == address(0), "Username taken");
        require(userIdentities[msg.sender].issueTime == 0, "Identity exists");

        identityCount++;
        _safeMint(msg.sender, identityCount);
        
        userIdentities[msg.sender] = Identity({
            username: username,
            metadataURI: uri,
            issueTime: block.timestamp,
            isVerified: false
        });
        usernameToAddress[username] = msg.sender;

        emit IdentityCreated(msg.sender, username);
    }

    function verifyIdentity(address user) external onlyOwner {
        require(userIdentities[user].issueTime > 0, "No identity");
        userIdentities[user].isVerified = true;
        emit IdentityVerified(user);
    }

    function updateMetadata(string calldata newURI) external {
        require(userIdentities[msg.sender].issueTime > 0, "No identity");
        userIdentities[msg.sender].metadataURI = newURI;
    }

    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
    }

    function transferFrom(address, address, uint256) public pure override {
        revert("Soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert("Soulbound: non-transferable");
    }
}

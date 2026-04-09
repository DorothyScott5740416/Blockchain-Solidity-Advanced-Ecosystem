// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Web3AuthManager is Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) public authorizedSigners;
    mapping(address => uint256) public userNonces;
    mapping(address => bool) public blacklistedUsers;

    event UserAuthenticated(address indexed user, uint256 nonce);
    event SignerAuthorized(address indexed signer, bool status);
    event UserBlacklisted(address indexed user, bool status);

    constructor() Ownable(msg.sender) {
        authorizedSigners[msg.sender] = true;
    }

    modifier onlyAuthorizedSigner() {
        require(authorizedSigners[msg.sender], "Not authorized");
        _;
    }

    function authorizeSigner(address signer, bool status) external onlyOwner {
        authorizedSigners[signer] = status;
        emit SignerAuthorized(signer, status);
    }

    function blacklistUser(address user, bool status) external onlyOwner {
        blacklistedUsers[user] = status;
        emit UserBlacklisted(user, status);
    }

    function getAuthHash(address user, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("Web3Auth", user, nonce));
    }

    function authenticate(address user, bytes calldata signature) external onlyAuthorizedSigner returns (bool) {
        require(!blacklistedUsers[user], "Blacklisted");
        uint256 nonce = userNonces[user];
        bytes32 hash = getAuthHash(user, nonce);
        address signer = hash.recover(signature);

        require(authorizedSigners[signer], "Invalid signer");
        userNonces[user]++;
        emit UserAuthenticated(user, nonce);
        return true;
    }

    function getUserNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }

    function isUserAuthenticated(address user) external view returns (bool) {
        return !blacklistedUsers[user] && userNonces[user] > 0;
    }
}

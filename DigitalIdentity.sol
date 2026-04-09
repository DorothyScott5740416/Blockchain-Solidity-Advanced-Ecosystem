// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract DigitalIdentity is Ownable {
    struct IdentityData {
        string fullName;
        string emailHash;
        string phoneHash;
        uint256 creationTime;
        bool isActive;
        address verifier;
    }

    mapping(address => IdentityData) public identities;
    mapping(address => bool) public verifiers;
    uint256 public identityCount;

    event IdentityCreated(address indexed user, string name);
    event IdentityVerified(address indexed user, address verifier);
    event IdentityRevoked(address indexed user);

    constructor() Ownable(msg.sender) {
        verifiers[msg.sender] = true;
    }

    modifier onlyVerifier() {
        require(verifiers[msg.sender], "Not verifier");
        _;
    }

    function addVerifier(address verifier) external onlyOwner {
        verifiers[verifier] = true;
    }

    function createIdentity(string calldata name, string calldata email, string calldata phone) external {
        require(identities[msg.sender].creationTime == 0, "Identity exists");
        identityCount++;
        identities[msg.sender] = IdentityData({
            fullName: name,
            emailHash: email,
            phoneHash: phone,
            creationTime: block.timestamp,
            isActive: true,
            verifier: address(0)
        });
        emit IdentityCreated(msg.sender, name);
    }

    function verifyIdentity(address user) external onlyVerifier {
        require(identities[user].creationTime > 0, "No identity");
        identities[user].verifier = msg.sender;
        emit IdentityVerified(user, msg.sender);
    }

    function revokeIdentity(address user) external onlyOwner {
        identities[user].isActive = false;
        emit IdentityRevoked(user);
    }

    function updateIdentity(string calldata newName, string calldata newEmail, string calldata newPhone) external {
        require(identities[msg.sender].isActive, "Identity inactive");
        IdentityData storage id = identities[msg.sender];
        id.fullName = newName;
        id.emailHash = newEmail;
        id.phoneHash = newPhone;
    }

    function isVerified(address user) external view returns (bool) {
        return identities[user].verifier != address(0) && identities[user].isActive;
    }
}

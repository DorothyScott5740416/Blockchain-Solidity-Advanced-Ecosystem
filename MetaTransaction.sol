// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MetaTransaction is Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) public relayers;
    mapping(address => uint256) public nonces;

    event MetaTransactionExecuted(address indexed user, address indexed relayer, bytes32 hash);
    event RelayerUpdated(address indexed relayer, bool status);

    constructor() Ownable(msg.sender) {
        relayers[msg.sender] = true;
    }

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not relayer");
        _;
    }

    function setRelayer(address relayer, bool status) external onlyOwner {
        relayers[relayer] = status;
        emit RelayerUpdated(relayer, status);
    }

    function getTransactionHash(address user, bytes calldata data, uint256 nonce) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, data, nonce));
    }

    function executeMetaTransaction(address user, bytes calldata data, bytes calldata signature) external onlyRelayer returns (bool, bytes memory) {
        bytes32 txHash = getTransactionHash(user, data, nonces[user]);
        address signer = txHash.recover(signature);
        require(signer == user, "Invalid signature");

        nonces[user]++;
        (bool success, bytes memory result) = address(this).call(data);
        emit MetaTransactionExecuted(user, msg.sender, txHash);
        return (success, result);
    }

    function transferTokens(address token, address to, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    function transferNFT(address nft, address to, uint256 tokenId) external {
        IERC721(nft).transferFrom(msg.sender, to, tokenId);
    }
}

interface IERC20 { function transferFrom(address,address,uint256) external; }
interface IERC721 { function transferFrom(address,address,uint256) external; }

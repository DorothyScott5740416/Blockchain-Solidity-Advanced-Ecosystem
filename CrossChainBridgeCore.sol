// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CrossChainBridgeCore is Ownable, Pausable {
    uint256 public chainId;
    address public validator;
    uint256 public bridgeFee = 100; // 1%

    struct BridgeTransfer {
        uint256 transferId;
        address sender;
        address recipient;
        uint256 amount;
        uint256 sourceChain;
        uint256 targetChain;
        bool isCompleted;
    }

    mapping(uint256 => BridgeTransfer) public transfers;
    mapping(address => uint256) public userNonces;
    uint256 public transferCount;

    event BridgeInitiated(uint256 indexed transferId, address indexed sender, uint256 targetChain);
    event BridgeCompleted(uint256 indexed transferId, address indexed recipient);

    constructor(uint256 _chainId, address _validator) Ownable(msg.sender) {
        chainId = _chainId;
        validator = _validator;
    }

    function initiateBridge(address token, address recipient, uint256 amount, uint256 targetChain) external whenNotPaused {
        require(amount > 0, "Amount zero");
        require(targetChain != chainId, "Same chain");

        uint256 fee = (amount * bridgeFee) / 10000;
        uint256 transferAmount = amount - fee;

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        transferCount++;
        uint256 newId = transferCount;

        transfers[newId] = BridgeTransfer({
            transferId: newId,
            sender: msg.sender,
            recipient: recipient,
            amount: transferAmount,
            sourceChain: chainId,
            targetChain: targetChain,
            isCompleted: false
        });

        userNonces[msg.sender]++;
        emit BridgeInitiated(newId, msg.sender, targetChain);
    }

    function completeBridge(uint256 transferId, address token, bytes calldata signature) external onlyValidator {
        BridgeTransfer storage transfer = transfers[transferId];
        require(!transfer.isCompleted, "Completed");
        require(transfer.targetChain == chainId, "Wrong chain");

        transfer.isCompleted = true;
        IERC20(token).transfer(transfer.recipient, transfer.amount);
        emit BridgeCompleted(transferId, transfer.recipient);
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Not validator");
        _;
    }

    function updateValidator(address newValidator) external onlyOwner {
        validator = newValidator;
    }

    function pauseBridge() external onlyOwner {
        _pause();
    }

    function unpauseBridge() external onlyOwner {
        _unpause();
    }
}

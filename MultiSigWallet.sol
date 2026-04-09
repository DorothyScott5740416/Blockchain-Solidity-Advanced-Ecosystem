// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    address[] public owners;
    uint256 public requiredConfirmations;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 value);
    event TransactionCreated(uint256 indexed txId, address indexed to);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "No owners");
        require(_required > 0 && _required <= _owners.length, "Invalid required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");
            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function createTransaction(address to, uint256 value, bytes calldata data) external onlyOwner returns (uint256) {
        transactionCount++;
        uint256 newId = transactionCount;
        transactions[newId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        });
        emit TransactionCreated(newId, to);
        return newId;
    }

    function confirmTransaction(uint256 txId) external onlyOwner {
        Transaction storage tx = transactions[txId];
        require(!tx.executed, "Executed");
        require(!confirmations[txId][msg.sender], "Already confirmed");

        confirmations[txId][msg.sender] = true;
        tx.confirmations++;
        emit TransactionConfirmed(txId, msg.sender);

        if (tx.confirmations >= requiredConfirmations) {
            executeTransaction(txId);
        }
    }

    function executeTransaction(uint256 txId) internal {
        Transaction storage tx = transactions[txId];
        require(tx.confirmations >= requiredConfirmations, "Not enough confirmations");
        require(!tx.executed, "Executed");

        tx.executed = true;
        (bool success, ) = tx.to.call{value: tx.value}(tx.data);
        require(success, "Tx failed");
        emit TransactionExecuted(txId);
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }
}

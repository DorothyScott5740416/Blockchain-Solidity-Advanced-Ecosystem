// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LotterySystem is Ownable, ReentrancyGuard {
    uint256 public ticketPrice = 0.01 ether;
    uint256 public maxTickets = 1000;
    uint256 public lotteryId;
    uint256 public prizePool;
    address[] public participants;
    bool public lotteryActive;

    mapping(uint256 => address) public lotteryWinners;
    mapping(address => uint256) public userTickets;

    event LotteryStarted(uint256 indexed id, uint256 prize);
    event TicketPurchased(address indexed buyer, uint256 amount);
    event LotteryWinner(uint256 indexed id, address winner, uint256 prize);

    constructor() Ownable(msg.sender) {}

    function startLottery() external onlyOwner {
        require(!lotteryActive, "Lottery active");
        lotteryId++;
        lotteryActive = true;
        participants = new address[](0);
        prizePool = 0;
        emit LotteryStarted(lotteryId, prizePool);
    }

    function buyTickets(uint256 amount) external payable nonReentrant {
        require(lotteryActive, "Lottery inactive");
        require(amount > 0, "Amount zero");
        require(msg.value == ticketPrice * amount, "Wrong value");
        require(participants.length + amount <= maxTickets, "Max tickets");

        for (uint256 i = 0; i < amount; i++) {
            participants.push(msg.sender);
        }
        userTickets[msg.sender] += amount;
        prizePool += msg.value;
        emit TicketPurchased(msg.sender, amount);
    }

    function drawWinner() external onlyOwner {
        require(lotteryActive, "Lottery inactive");
        require(participants.length > 0, "No participants");

        uint256 winnerIndex = random() % participants.length;
        address winner = participants[winnerIndex];
        lotteryWinners[lotteryId] = winner;

        uint256 fee = prizePool / 10;
        uint256 winnerPrize = prizePool - fee;

        payable(winner).transfer(winnerPrize);
        payable(owner()).transfer(fee);

        lotteryActive = false;
        emit LotteryWinner(lotteryId, winner, winnerPrize);
    }

    function random() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, participants.length)));
    }

    function setTicketPrice(uint256 newPrice) external onlyOwner {
        require(!lotteryActive, "Lottery active");
        ticketPrice = newPrice;
    }
}

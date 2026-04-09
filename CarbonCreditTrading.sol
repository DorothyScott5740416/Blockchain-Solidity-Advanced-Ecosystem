// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CarbonCreditTrading is ERC20, Ownable, ReentrancyGuard {
    uint256 public creditPrice = 0.001 ether;
    address public validator;
    uint256 public totalCarbonCredits;

    struct CreditProject {
        uint256 id;
        string name;
        uint256 creditsIssued;
        address creator;
        bool isVerified;
    }

    mapping(uint256 => CreditProject) public projects;
    uint256 public projectIdCounter;

    event ProjectCreated(uint256 indexed id, string name, uint256 credits);
    event CreditsPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event ProjectVerified(uint256 indexed id);

    constructor() ERC20("CarbonCredit", "CREDIT") Ownable(msg.sender) {
        validator = msg.sender;
    }

    function createProject(string calldata name, uint256 credits) external {
        require(credits > 0, "Zero credits");
        projectIdCounter++;
        uint256 newId = projectIdCounter;
        projects[newId] = CreditProject({
            id: newId,
            name: name,
            creditsIssued: credits,
            creator: msg.sender,
            isVerified: false
        });
        emit ProjectCreated(newId, name, credits);
    }

    function verifyProject(uint256 projectId) external onlyValidator {
        CreditProject storage proj = projects[projectId];
        require(!proj.isVerified, "Verified");
        proj.isVerified = true;
        _mint(proj.creator, proj.creditsIssued * 10**18);
        totalCarbonCredits += proj.creditsIssued;
        emit ProjectVerified(projectId);
    }

    function purchaseCredits(uint256 amount) external payable nonReentrant {
        require(amount > 0, "Amount zero");
        uint256 totalCost = amount * creditPrice;
        require(msg.value >= totalCost, "Insufficient payment");
        _transfer(owner(), msg.sender, amount * 10**18);
        emit CreditsPurchased(msg.sender, amount, totalCost);
    }

    function retireCredits(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount * 10**18, "Insufficient credits");
        _burn(msg.sender, amount * 10**18);
        totalCarbonCredits -= amount;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Not validator");
        _;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }
}

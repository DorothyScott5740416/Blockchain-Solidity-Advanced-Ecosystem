// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DAOTreasury is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public daoGovernance;
    uint256 public proposalCount;

    struct TreasuryProposal {
        uint256 id;
        address recipient;
        uint256 amount;
        address token;
        string description;
        bool executed;
        uint256 forVotes;
        uint256 againstVotes;
    }

    mapping(uint256 => TreasuryProposal) public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address recipient, uint256 amount);
    event VoteCast(uint256 indexed id, address voter, bool support);
    event FundsReleased(uint256 indexed id, address recipient, uint256 amount);

    constructor(address _governance) Ownable(msg.sender) {
        daoGovernance = _governance;
    }

    modifier onlyGovernance() {
        require(msg.sender == daoGovernance, "Not governance");
        _;
    }

    function createTreasuryProposal(address recipient, uint256 amount, address token, string calldata desc) external onlyGovernance returns (uint256) {
        proposalCount++;
        uint256 newId = proposalCount;
        proposals[newId] = TreasuryProposal({
            id: newId,
            recipient: recipient,
            amount: amount,
            token: token,
            description: desc,
            executed: false,
            forVotes: 0,
            againstVotes: 0
        });
        emit ProposalCreated(newId, recipient, amount);
        return newId;
    }

    function castVote(uint256 proposalId, bool support) external onlyGovernance {
        TreasuryProposal storage prop = proposals[proposalId];
        require(!prop.executed, "Executed");
        require(!hasVoted[msg.sender][proposalId], "Voted");

        hasVoted[msg.sender][proposalId] = true;
        if (support) prop.forVotes++;
        else prop.againstVotes++;
        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external onlyGovernance nonReentrant {
        TreasuryProposal storage prop = proposals[proposalId];
        require(!prop.executed, "Executed");
        require(prop.forVotes > prop.againstVotes, "Rejected");

        prop.executed = true;
        if (prop.token == address(0)) {
            payable(prop.recipient).transfer(prop.amount);
        } else {
            IERC20(prop.token).safeTransfer(prop.recipient, prop.amount);
        }
        emit FundsReleased(proposalId, prop.recipient, prop.amount);
    }

    receive() external payable {}
}

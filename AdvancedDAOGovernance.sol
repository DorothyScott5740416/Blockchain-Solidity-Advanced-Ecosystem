// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AdvancedDAOGovernance is Ownable {
    IERC20 public governanceToken;
    uint256 public proposalCount;
    uint256 public quorum = 500; // 5%
    uint256 public votingPeriod = 7 days;

    enum ProposalState { PENDING, ACTIVE, SUCCESS, FAILED, EXECUTED }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        ProposalState state;
        bytes callData;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => uint256) public lastProposalTime;

    event ProposalCreated(uint256 indexed id, address indexed proposer);
    event VoteCast(uint256 indexed id, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address _govToken) Ownable(msg.sender) {
        governanceToken = IERC20(_govToken);
    }

    function createProposal(string calldata description, bytes calldata callData) external returns (uint256) {
        uint256 balance = governanceToken.balanceOf(msg.sender);
        require(balance >= 1000e18, "Need 1000 tokens");
        require(block.timestamp > lastProposalTime[msg.sender] + 1 days, "1 proposal/day");

        proposalCount++;
        uint256 newId = proposalCount;
        proposals[newId] = Proposal({
            id: newId,
            proposer: msg.sender,
            description: description,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            forVotes: 0,
            againstVotes: 0,
            state: ProposalState.ACTIVE,
            callData: callData
        });

        lastProposalTime[msg.sender] = block.timestamp;
        emit ProposalCreated(newId, msg.sender);
        return newId;
    }

    function castVote(uint256 proposalId, bool support) external {
        Proposal storage prop = proposals[proposalId];
        require(prop.state == ProposalState.ACTIVE, "Not active");
        require(block.timestamp < prop.endTime, "Voting ended");
        require(!hasVoted[msg.sender][proposalId], "Voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[msg.sender][proposalId] = true;
        if (support) prop.forVotes += weight;
        else prop.againstVotes += weight;

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function finalizeProposal(uint256 proposalId) external {
        Proposal storage prop = proposals[proposalId];
        require(prop.state == ProposalState.ACTIVE, "Not active");
        require(block.timestamp > prop.endTime, "Voting active");

        uint256 totalVotes = prop.forVotes + prop.againstVotes;
        uint256 totalSupply = governanceToken.totalSupply();
        bool quorumReached = (totalVotes * 10000) / totalSupply >= quorum;

        if (quorumReached && prop.forVotes > prop.againstVotes) {
            prop.state = ProposalState.SUCCESS;
        } else {
            prop.state = ProposalState.FAILED;
        }
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage prop = proposals[proposalId];
        require(prop.state == ProposalState.SUCCESS, "Not success");
        (bool success, ) = address(this).call(prop.callData);
        require(success, "Execution failed");
        prop.state = ProposalState.EXECUTED;
        emit ProposalExecuted(proposalId);
    }
}

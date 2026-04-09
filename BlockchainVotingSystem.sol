// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BlockchainVotingSystem is Ownable {
    struct Election {
        string name;
        string[] candidates;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        mapping(uint256 => uint256) votes;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Election) public elections;
    uint256 public electionCount;

    event ElectionCreated(uint256 indexed id, string name, string[] candidates);
    event VoteCast(uint256 indexed electionId, uint256 indexed candidateId, address voter);
    event ElectionEnded(uint256 indexed id);

    constructor() Ownable(msg.sender) {}

    function createElection(string calldata name, string[] calldata candidates, uint256 duration) external onlyOwner returns (uint256) {
        require(candidates.length >= 2, "Need 2+ candidates");
        electionCount++;
        uint256 newId = electionCount;

        Election storage election = elections[newId];
        election.name = name;
        election.startTime = block.timestamp;
        election.endTime = block.timestamp + duration;
        election.isActive = true;

        for (uint256 i = 0; i < candidates.length; i++) {
            election.candidates.push(candidates[i]);
        }

        emit ElectionCreated(newId, name, candidates);
        return newId;
    }

    function castVote(uint256 electionId, uint256 candidateId) external {
        Election storage election = elections[electionId];
        require(election.isActive, "Election inactive");
        require(block.timestamp >= election.startTime && block.timestamp <= election.endTime, "Voting window closed");
        require(!election.hasVoted[msg.sender], "Already voted");
        require(candidateId < election.candidates.length, "Invalid candidate");

        election.hasVoted[msg.sender] = true;
        election.votes[candidateId]++;
        emit VoteCast(electionId, candidateId, msg.sender);
    }

    function endElection(uint256 electionId) external onlyOwner {
        Election storage election = elections[electionId];
        require(election.isActive, "Already ended");
        election.isActive = false;
        emit ElectionEnded(electionId);
    }

    function getCandidateVotes(uint256 electionId, uint256 candidateId) external view returns (uint256) {
        return elections[electionId].votes[candidateId];
    }

    function getElectionCandidates(uint256 electionId) external view returns (string[] memory) {
        return elections[electionId].candidates;
    }
}

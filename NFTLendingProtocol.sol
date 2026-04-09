// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTLendingProtocol is Ownable, ReentrancyGuard {
    IERC20 public immutable loanToken;
    uint256 public loanFee = 500; // 5%
    uint256 public loanDuration = 30 days;

    struct Loan {
        address borrower;
        address nftContract;
        uint256 tokenId;
        uint256 loanAmount;
        uint256 dueTime;
        bool isRepaid;
        bool isLiquidated;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => mapping(uint256 => bool)) public nftUsed;
    uint256 public loanIdCounter;

    event LoanCreated(uint256 indexed id, address borrower, uint256 amount);
    event LoanRepaid(uint256 indexed id);
    event LoanLiquidated(uint256 indexed id);

    constructor(address _loanToken) Ownable(msg.sender) {
        loanToken = IERC20(_loanToken);
    }

    function createLoan(address nft, uint256 tokenId, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount zero");
        require(!nftUsed[nft][tokenId], "NFT used");
        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "Not owner");

        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);
        loanIdCounter++;
        uint256 newId = loanIdCounter;

        loans[newId] = Loan({
            borrower: msg.sender,
            nftContract: nft,
            tokenId: tokenId,
            loanAmount: amount,
            dueTime: block.timestamp + loanDuration,
            isRepaid: false,
            isLiquidated: false
        });

        nftUsed[nft][tokenId] = true;
        loanToken.transfer(msg.sender, amount);
        emit LoanCreated(newId, msg.sender, amount);
    }

    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(!loan.isRepaid && !loan.isLiquidated, "Loan closed");
        require(msg.sender == loan.borrower, "Not borrower");

        uint256 totalRepay = loan.loanAmount + (loan.loanAmount * loanFee) / 10000;
        loanToken.transferFrom(msg.sender, address(this), totalRepay);

        loan.isRepaid = true;
        nftUsed[loan.nftContract][loan.tokenId] = false;
        IERC721(loan.nftContract).transferFrom(address(this), loan.borrower, loan.tokenId);
        emit LoanRepaid(loanId);
    }

    function liquidateLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];
        require(!loan.isRepaid && !loan.isLiquidated, "Loan closed");
        require(block.timestamp > loan.dueTime, "Not due");

        loan.isLiquidated = true;
        nftUsed[loan.nftContract][loan.tokenId] = false;
        IERC721(loan.nftContract).transferFrom(address(this), owner(), loan.tokenId);
        emit LoanLiquidated(loanId);
    }

    function updateLoanTerms(uint256 newFee, uint256 newDuration) external onlyOwner {
        loanFee = newFee;
        loanDuration = newDuration;
    }
}

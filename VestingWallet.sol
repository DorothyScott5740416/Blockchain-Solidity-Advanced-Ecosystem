// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingWallet is Ownable {
    IERC20 public immutable token;
    address public beneficiary;
    uint256 public start;
    uint256 public duration;
    uint256 public cliff;
    uint256 public released;

    event TokensReleased(uint256 amount);
    event BeneficiaryUpdated(address newBeneficiary);

    constructor(address _token, address _beneficiary, uint256 _start, uint256 _duration, uint256 _cliff) Ownable(msg.sender) {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_duration > 0, "Duration zero");
        require(_cliff <= _duration, "Cliff too long");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = _start;
        duration = _duration;
        cliff = _cliff;
    }

    function releasableAmount() public view returns (uint256) {
        if (block.timestamp < start + cliff) return 0;
        if (block.timestamp >= start + duration) {
            return token.balanceOf(address(this)) - released;
        }

        uint256 total = token.balanceOf(address(this)) + released;
        uint256 elapsed = block.timestamp - start;
        uint256 vested = (total * elapsed) / duration;
        return vested - released;
    }

    function release() external onlyBeneficiary {
        uint256 amount = releasableAmount();
        require(amount > 0, "No tokens to release");

        released += amount;
        token.transfer(beneficiary, amount);
        emit TokensReleased(amount);
    }

    function updateBeneficiary(address newBeneficiary) external onlyOwner {
        require(newBeneficiary != address(0), "Invalid address");
        beneficiary = newBeneficiary;
        emit BeneficiaryUpdated(newBeneficiary);
    }

    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "Not beneficiary");
        _;
    }
}

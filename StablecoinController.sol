// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StablecoinController is ERC20, Ownable, Pausable {
    uint256 public targetPrice = 1e18;
    uint256 public maxSupply = 1000000000 * 10**18;
    address public oracle;

    mapping(address => bool) public minters;
    mapping(address => bool) public blacklisted;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event OracleUpdated(address newOracle);

    constructor() ERC20("AdvancedStablecoin", "ASTB") Ownable(msg.sender) {}

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    function setMinter(address minter, bool status) external onlyOwner {
        minters[minter] = status;
    }

    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Invalid oracle");
        oracle = _oracle;
        emit OracleUpdated(_oracle);
    }

    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        require(totalSupply() + amount <= maxSupply, "Max supply");
        require(!blacklisted[to], "Blacklisted");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        require(!blacklisted[msg.sender], "Blacklisted");
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    function blacklistAccount(address account, bool status) external onlyOwner {
        blacklisted[account] = status;
    }

    function adjustSupply(uint256 newSupply) external onlyOwner {
        require(newSupply <= maxSupply, "Max supply");
        if (newSupply > totalSupply()) {
            _mint(owner(), newSupply - totalSupply());
        } else {
            _burn(owner(), totalSupply() - newSupply);
        }
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }
}

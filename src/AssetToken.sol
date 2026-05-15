// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract AssetToken is ERC20, ERC20Burnable, ERC20Permit, Ownable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor() ERC20("Asset Token", "ASSET") ERC20Permit("Asset Token") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(BURNER_ROLE, _msgSender());
    }

    function mint(address to, uint256 amount) public {
        require(owner() == _msgSender() || hasRole(MINTER_ROLE, _msgSender()), "AssetToken: not minter");
        require(totalSupply() + amount <= MAX_SUPPLY, "AssetToken: max supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
        emit Burned(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    function burnBackingFrom(address account, uint256 amount) external {
        require(owner() == _msgSender() || hasRole(BURNER_ROLE, _msgSender()), "AssetToken: not burner");
        _burn(account, amount);
        emit Burned(account, amount);
    }

    function remainingSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

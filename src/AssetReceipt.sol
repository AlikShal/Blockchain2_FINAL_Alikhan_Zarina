// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract AssetReceipt is ERC1155Supply, AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant URI_MANAGER_ROLE = keccak256("URI_MANAGER_ROLE");

    mapping(uint256 => uint256) public maxSupply;
    mapping(uint256 => string) private _tokenURIs;

    event ReceiptConfigured(uint256 indexed id, uint256 maxSupply, string uri);
    event ReceiptMinted(address indexed to, uint256 indexed id, uint256 amount);

    constructor(string memory baseURI, address admin) ERC1155(baseURI) {
        require(admin != address(0), "AssetReceipt: admin zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
        _grantRole(URI_MANAGER_ROLE, admin);
    }

    function configureReceipt(uint256 id, uint256 maxSupply_, string calldata tokenURI)
        external
        onlyRole(URI_MANAGER_ROLE)
    {
        require(id != 0, "AssetReceipt: id zero");
        require(maxSupply_ > 0, "AssetReceipt: max supply zero");
        require(totalSupply(id) <= maxSupply_, "AssetReceipt: below minted");
        maxSupply[id] = maxSupply_;
        _tokenURIs[id] = tokenURI;
        emit ReceiptConfigured(id, maxSupply_, tokenURI);
    }

    // slither-disable-next-line reentrancy-events
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyRole(ISSUER_ROLE) {
        require(to != address(0), "AssetReceipt: to zero");
        require(maxSupply[id] > 0, "AssetReceipt: not configured");
        require(totalSupply(id) + amount <= maxSupply[id], "AssetReceipt: max supply");
        _mint(to, id, amount, data);
        emit ReceiptMinted(to, id, amount);
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[id];
        if (bytes(tokenURI).length == 0) return super.uri(id);
        return tokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

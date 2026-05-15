// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract AssetRegistry is AccessControl, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ISSUER_ADMIN_ROLE = keccak256("ISSUER_ADMIN_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct AssetRecord {
        address issuer;
        address reserveAsset;
        address assetToken;
        address vault;
        uint256 maxSupply;
        string metadataURI;
        bool active;
    }

    bool private _initialized;
    uint256 public assetCount;
    mapping(bytes32 => AssetRecord) private _assets;

    event RegistryInitialized(address indexed admin);
    event IssuerAuthorized(address indexed issuer, address indexed admin);
    event IssuerRevoked(address indexed issuer, address indexed admin);
    event AssetRegistered(
        bytes32 indexed assetId,
        address indexed issuer,
        address reserveAsset,
        address assetToken,
        address vault,
        uint256 maxSupply,
        string metadataURI
    );
    event AssetActiveSet(bytes32 indexed assetId, bool active);

    function initialize(address admin) public {
        require(!_initialized, "AssetRegistry: initialized");
        require(admin != address(0), "AssetRegistry: admin zero");
        _initialized = true;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(ISSUER_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        emit RegistryInitialized(admin);
    }

    function authorizeIssuer(address issuer) external onlyRole(ISSUER_ADMIN_ROLE) {
        require(issuer != address(0), "AssetRegistry: issuer zero");
        _grantRole(ISSUER_ROLE, issuer);
        emit IssuerAuthorized(issuer, _msgSender());
    }

    function revokeIssuer(address issuer) external onlyRole(ISSUER_ADMIN_ROLE) {
        _revokeRole(ISSUER_ROLE, issuer);
        emit IssuerRevoked(issuer, _msgSender());
    }

    function registerAsset(
        bytes32 assetId,
        address reserveAsset,
        address assetToken,
        address vault,
        uint256 maxSupply,
        string calldata metadataURI
    ) external onlyRole(ISSUER_ROLE) {
        require(assetId != bytes32(0), "AssetRegistry: asset id zero");
        require(_assets[assetId].issuer == address(0), "AssetRegistry: exists");
        require(reserveAsset != address(0), "AssetRegistry: reserve zero");
        require(assetToken != address(0), "AssetRegistry: token zero");
        require(vault != address(0), "AssetRegistry: vault zero");
        require(maxSupply > 0, "AssetRegistry: max supply zero");

        _assets[assetId] = AssetRecord({
            issuer: _msgSender(),
            reserveAsset: reserveAsset,
            assetToken: assetToken,
            vault: vault,
            maxSupply: maxSupply,
            metadataURI: metadataURI,
            active: true
        });
        assetCount++;

        emit AssetRegistered(assetId, _msgSender(), reserveAsset, assetToken, vault, maxSupply, metadataURI);
    }

    function pauseAsset(bytes32 assetId) external onlyRole(PAUSER_ROLE) {
        _setAssetActive(assetId, false);
    }

    function unpauseAsset(bytes32 assetId) external onlyRole(PAUSER_ROLE) {
        _setAssetActive(assetId, true);
    }

    function setAssetActive(bytes32 assetId, bool active) external onlyRole(PAUSER_ROLE) {
        _setAssetActive(assetId, active);
    }

    function _setAssetActive(bytes32 assetId, bool active) internal {
        require(_assets[assetId].issuer != address(0), "AssetRegistry: missing");
        _assets[assetId].active = active;
        emit AssetActiveSet(assetId, active);
    }

    function getAsset(bytes32 assetId) external view returns (AssetRecord memory) {
        require(_assets[assetId].issuer != address(0), "AssetRegistry: missing");
        return _assets[assetId];
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyRole(UPGRADER_ROLE) {
        require(newImplementation != address(0), "AssetRegistry: implementation zero");
    }
}

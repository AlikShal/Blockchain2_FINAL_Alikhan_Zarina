// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetVault.sol";

contract VaultFactory {
    event VaultCreated(address indexed vault, address indexed backingAsset, address indexed assetToken, bytes32 salt);

    function createVault(address backingAsset, address assetToken) external returns (address vault) {
        vault = address(new AssetVault(backingAsset, assetToken));
        emit VaultCreated(vault, backingAsset, assetToken, bytes32(0));
    }

    function createVaultDeterministic(address backingAsset, address assetToken, bytes32 salt)
        external
        returns (address vault)
    {
        vault = address(new AssetVault{salt: salt}(backingAsset, assetToken));
        emit VaultCreated(vault, backingAsset, assetToken, salt);
    }

    function predictVaultAddress(address backingAsset, address assetToken, bytes32 salt)
        external
        view
        returns (address)
    {
        // slither-disable-next-line too-many-digits
        bytes32 initCodeHash =
            keccak256(abi.encodePacked(type(AssetVault).creationCode, abi.encode(backingAsset, assetToken)));
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, initCodeHash));
        return address(uint160(uint256(digest)));
    }
}

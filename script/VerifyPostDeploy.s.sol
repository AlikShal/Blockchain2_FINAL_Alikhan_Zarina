// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../src/AssetToken.sol";
import "../src/AssetVault.sol";

contract VerifyPostDeploy is Script {
    function run() external view {
        address assetTokenAddress = vm.envAddress("ASSET_TOKEN");
        address assetVaultAddress = vm.envAddress("ASSET_VAULT");

        AssetToken assetToken = AssetToken(assetTokenAddress);
        AssetVault assetVault = AssetVault(assetVaultAddress);

        require(address(assetVault.assetToken()) == assetTokenAddress, "Vault asset token mismatch");
        require(assetToken.owner() == assetVaultAddress, "Asset token owner is not the vault");
        require(assetToken.hasRole(assetToken.MINTER_ROLE(), assetVaultAddress), "Vault missing minter role");
        require(assetToken.hasRole(assetToken.BURNER_ROLE(), assetVaultAddress), "Vault missing burner role");
        require(address(assetVault.asset()) != address(0), "Vault backing asset missing");

        console2.log("Post-deploy protocol checks passed.");
    }
}

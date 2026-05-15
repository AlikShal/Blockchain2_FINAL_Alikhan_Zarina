// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

import "../src/AssetRegistry.sol";
import "../src/AssetToken.sol";
import "../src/AssetVault.sol";
import "../src/Governance.sol";

contract VerifyPostDeploy is Script {
    function run() external view {
        address deployerAddress = vm.envAddress("DEPLOYER_ADDRESS");
        address assetTokenAddress = vm.envAddress("ASSET_TOKEN");
        address assetVaultAddress = vm.envAddress("ASSET_VAULT");
        address assetRegistryAddress = vm.envAddress("ASSET_REGISTRY");
        address governanceTokenAddress = vm.envAddress("GOVERNANCE_TOKEN");
        address governorAddress = vm.envAddress("GOVERNOR");
        address timelockAddress = vm.envAddress("TIMELOCK");

        AssetToken assetToken = AssetToken(assetTokenAddress);
        AssetVault assetVault = AssetVault(assetVaultAddress);
        AssetRegistry assetRegistry = AssetRegistry(assetRegistryAddress);
        GovernanceToken governanceToken = GovernanceToken(governanceTokenAddress);
        ProtocolGovernor governor = ProtocolGovernor(payable(governorAddress));
        TimelockController timelock = TimelockController(payable(timelockAddress));

        require(address(assetVault.assetToken()) == assetTokenAddress, "Vault asset token mismatch");
        require(assetToken.owner() == timelockAddress, "Asset token owner is not the timelock");
        require(assetToken.hasRole(assetToken.MINTER_ROLE(), assetVaultAddress), "Vault missing minter role");
        require(assetToken.hasRole(assetToken.BURNER_ROLE(), assetVaultAddress), "Vault missing burner role");
        require(assetToken.hasRole(assetToken.DEFAULT_ADMIN_ROLE(), timelockAddress), "Timelock missing asset token admin");
        require(!assetToken.hasRole(assetToken.DEFAULT_ADMIN_ROLE(), deployerAddress), "Deployer still asset token admin");
        require(address(assetVault.asset()) != address(0), "Vault backing asset missing");
        require(governanceToken.owner() == timelockAddress, "Governance token owner is not the timelock");
        require(uint256(timelock.getMinDelay()) == 2 days, "Timelock delay mismatch");
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), governorAddress), "Governor missing proposer role");
        require(timelock.hasRole(timelock.CANCELLER_ROLE(), governorAddress), "Governor missing canceller role");
        require(!timelock.hasRole(timelock.TIMELOCK_ADMIN_ROLE(), deployerAddress), "Deployer still timelock admin");
        require(assetRegistry.hasRole(assetRegistry.DEFAULT_ADMIN_ROLE(), timelockAddress), "Timelock missing registry admin");
        require(assetRegistry.hasRole(assetRegistry.UPGRADER_ROLE(), timelockAddress), "Timelock missing upgrader role");
        require(assetRegistry.hasRole(assetRegistry.ISSUER_ADMIN_ROLE(), timelockAddress), "Timelock missing issuer admin");
        require(assetRegistry.hasRole(assetRegistry.PAUSER_ROLE(), timelockAddress), "Timelock missing pauser role");
        require(!assetRegistry.hasRole(assetRegistry.DEFAULT_ADMIN_ROLE(), deployerAddress), "Deployer still registry admin");
        require(governor.votingDelay() == governor.VOTING_DELAY_BLOCKS(), "Voting delay mismatch");
        require(governor.votingPeriod() == governor.VOTING_PERIOD_BLOCKS(), "Voting period mismatch");
        require(governor.proposalThreshold() == governor.PROPOSAL_THRESHOLD(), "Proposal threshold mismatch");
        require(governor.quorumNumerator() == governor.QUORUM_PERCENT(), "Governor quorum mismatch");

        console2.log("Post-deploy protocol checks passed.");
    }
}

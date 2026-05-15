// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/AMM.sol";
import "../src/AssetRegistry.sol";
import "../src/AssetToken.sol";
import "../src/AssetVault.sol";
import "../src/Governance.sol";
import "../src/VaultFactory.sol";
import "../src/mocks/MockERC20.sol";

contract Deploy is Script {
    address private deployer;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        MockERC20 backingAsset = new MockERC20("Mock USD", "mUSD", 18);
        MockERC20 quoteAsset = new MockERC20("Mock Quote", "mQUOTE", 18);
        AssetToken assetToken = new AssetToken();
        GovernanceToken governanceToken = new GovernanceToken();
        AssetVault assetVault = new AssetVault(address(backingAsset), address(assetToken));
        AMM amm = new AMM(address(assetToken), address(quoteAsset));
        VaultFactory vaultFactory = new VaultFactory();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(2 days, proposers, executors, deployer);
        ProtocolGovernor governor = new ProtocolGovernor(governanceToken, timelock);

        AssetRegistry registryImplementation = new AssetRegistry();
        ERC1967Proxy registryProxy =
            new ERC1967Proxy(address(registryImplementation), abi.encodeCall(AssetRegistry.initialize, (deployer)));
        AssetRegistry registry = AssetRegistry(address(registryProxy));

        _configureTimelock(timelock, governor);
        _handoffRegistryAdmin(registry, timelock);
        _handoffAssetTokenAdmin(assetToken, assetVault, timelock);
        governanceToken.transferOwnership(address(timelock));

        vm.stopBroadcast();

        console2.log("BackingAsset:", address(backingAsset));
        console2.log("QuoteAsset:", address(quoteAsset));
        console2.log("AssetToken:", address(assetToken));
        console2.log("AssetVault:", address(assetVault));
        console2.log("AMM:", address(amm));
        console2.log("GovernanceToken:", address(governanceToken));
        console2.log("Governor:", address(governor));
        console2.log("Timelock:", address(timelock));
        console2.log("AssetRegistry:", address(registry));
        console2.log("VaultFactory:", address(vaultFactory));
    }

    function _configureTimelock(TimelockController timelock, ProtocolGovernor governor) internal {
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.renounceRole(timelock.TIMELOCK_ADMIN_ROLE(), deployer);
    }

    function _handoffRegistryAdmin(AssetRegistry registry, TimelockController timelock) internal {
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), address(timelock));
        registry.grantRole(registry.UPGRADER_ROLE(), address(timelock));
        registry.grantRole(registry.ISSUER_ADMIN_ROLE(), address(timelock));
        registry.grantRole(registry.PAUSER_ROLE(), address(timelock));
        registry.renounceRole(registry.UPGRADER_ROLE(), deployer);
        registry.renounceRole(registry.ISSUER_ADMIN_ROLE(), deployer);
        registry.renounceRole(registry.PAUSER_ROLE(), deployer);
        registry.renounceRole(registry.DEFAULT_ADMIN_ROLE(), deployer);
    }

    function _handoffAssetTokenAdmin(AssetToken assetToken, AssetVault assetVault, TimelockController timelock)
        internal
    {
        assetToken.grantRole(assetToken.DEFAULT_ADMIN_ROLE(), address(timelock));
        assetToken.grantRole(assetToken.MINTER_ROLE(), address(assetVault));
        assetToken.grantRole(assetToken.BURNER_ROLE(), address(assetVault));
        assetToken.renounceRole(assetToken.MINTER_ROLE(), deployer);
        assetToken.renounceRole(assetToken.BURNER_ROLE(), deployer);
        assetToken.renounceRole(assetToken.DEFAULT_ADMIN_ROLE(), deployer);
        assetToken.transferOwnership(address(timelock));
    }
}

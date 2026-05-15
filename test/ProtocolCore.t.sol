// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/AssetReceipt.sol";
import "../src/AssetRegistry.sol";
import "../src/AssetRegistryV2.sol";
import "../src/AssetToken.sol";
import "../src/AssetVault.sol";
import "../src/VaultFactory.sol";
import "../src/mocks/MockERC20.sol";

contract ProtocolCoreTest is Test {
    AssetRegistry public registry;
    AssetReceipt public receipt;
    AssetToken public assetToken;
    MockERC20 public reserve;
    AssetVault public vault;
    VaultFactory public factory;

    address public admin = address(this);
    address public issuer = address(0x1234);
    bytes32 public assetId = keccak256("KZ-BOND-001");

    function setUp() public {
        AssetRegistry implementation = new AssetRegistry();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), abi.encodeCall(AssetRegistry.initialize, (admin)));
        registry = AssetRegistry(address(proxy));
        registry.authorizeIssuer(issuer);

        receipt = new AssetReceipt("ipfs://base/", admin);
        reserve = new MockERC20("Reserve USD", "rUSD", 18);
        assetToken = new AssetToken();
        vault = new AssetVault(address(reserve), address(assetToken));
        assetToken.grantRole(assetToken.MINTER_ROLE(), address(vault));
        assetToken.grantRole(assetToken.BURNER_ROLE(), address(vault));
        factory = new VaultFactory();
    }

    function testRegistryInitialRoles() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.ISSUER_ROLE(), issuer));
        assertTrue(registry.hasRole(registry.PAUSER_ROLE(), admin));
    }

    function testIssuerCanRegisterAsset() public {
        vm.prank(issuer);
        registry.registerAsset(
            assetId, address(reserve), address(assetToken), address(vault), 1_000_000 ether, "ipfs://asset"
        );

        AssetRegistry.AssetRecord memory record = registry.getAsset(assetId);
        assertEq(record.issuer, issuer);
        assertEq(record.reserveAsset, address(reserve));
        assertTrue(record.active);
        assertEq(registry.assetCount(), 1);
    }

    function testUnauthorizedIssuerCannotRegister() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        registry.registerAsset(assetId, address(reserve), address(assetToken), address(vault), 1 ether, "ipfs://bad");
    }

    function testAdminCanRevokeIssuer() public {
        registry.revokeIssuer(issuer);
        assertFalse(registry.hasRole(registry.ISSUER_ROLE(), issuer));
    }

    function testAdminCanPauseRegisteredAsset() public {
        vm.prank(issuer);
        registry.registerAsset(
            assetId, address(reserve), address(assetToken), address(vault), 1_000_000 ether, "ipfs://asset"
        );

        registry.pauseAsset(assetId);
        AssetRegistry.AssetRecord memory record = registry.getAsset(assetId);
        assertFalse(record.active);

        registry.unpauseAsset(assetId);
        record = registry.getAsset(assetId);
        assertTrue(record.active);
    }

    function testNonPauserCannotPauseRegisteredAsset() public {
        vm.prank(issuer);
        registry.registerAsset(
            assetId, address(reserve), address(assetToken), address(vault), 1_000_000 ether, "ipfs://asset"
        );

        vm.prank(issuer);
        vm.expectRevert();
        registry.pauseAsset(assetId);
    }

    function testErc1155ReceiptMinting() public {
        uint256 tokenId = 1;
        receipt.configureReceipt(tokenId, 100, "ipfs://asset/1");
        receipt.mint(issuer, tokenId, 10, "");

        assertEq(receipt.balanceOf(issuer, tokenId), 10);
        assertEq(receipt.totalSupply(tokenId), 10);
        assertEq(receipt.uri(tokenId), "ipfs://asset/1");
    }

    function testErc1155ReceiptRejectsOverMint() public {
        uint256 tokenId = 2;
        receipt.configureReceipt(tokenId, 5, "ipfs://asset/2");

        vm.expectRevert(bytes("AssetReceipt: max supply"));
        receipt.mint(issuer, tokenId, 6, "");
    }

    function testErc1155ReceiptFallsBackToBaseUriWhenUnset() public view {
        assertEq(receipt.uri(999), "ipfs://base/");
    }

    function testRegistryUpgradeToV2() public {
        AssetRegistryV2 v2 = new AssetRegistryV2();
        registry.upgradeTo(address(v2));

        AssetRegistryV2 upgraded = AssetRegistryV2(address(registry));
        assertEq(upgraded.version(), "2.0.0");
        upgraded.pingV2();
        assertEq(upgraded.assetCount(), 0);
    }

    function testNonUpgraderCannotUpgrade() public {
        AssetRegistryV2 v2 = new AssetRegistryV2();

        vm.prank(issuer);
        vm.expectRevert();
        registry.upgradeTo(address(v2));
    }

    function testCreateFactoryVault() public {
        address created = factory.createVault(address(reserve), address(assetToken));
        assertTrue(created.code.length > 0);
        assertEq(address(AssetVault(created).assetToken()), address(assetToken));
    }

    function testCreate2FactoryVaultPredictsAddress() public {
        bytes32 salt = keccak256("vault-salt");
        address predicted = factory.predictVaultAddress(address(reserve), address(assetToken), salt);
        address created = factory.createVaultDeterministic(address(reserve), address(assetToken), salt);
        assertEq(created, predicted);
    }

    function testCreate2CannotReuseSalt() public {
        bytes32 salt = keccak256("same-salt");
        factory.createVaultDeterministic(address(reserve), address(assetToken), salt);
        vm.expectRevert();
        factory.createVaultDeterministic(address(reserve), address(assetToken), salt);
    }

    function testVaultIsERC4626() public view {
        assertEq(vault.name(), "Reserve Vault Share");
        assertEq(address(vault.asset()), address(reserve));
        assertEq(address(vault.backingAsset()), address(reserve));
        assertEq(vault.getReserveRatio(), 0);
    }

    function testVaultMintsReserveBackedAssetToken() public {
        address user = address(0xCAFE);
        reserve.mint(user, 100 ether);

        vm.startPrank(user);
        reserve.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(40 ether);
        vm.stopPrank();

        assertEq(shares, 40 ether);
        assertEq(assetToken.balanceOf(user), 40 ether);
        assertEq(vault.userDeposits(user), 40 ether);
    }

    function testVaultDepositForReceiver() public {
        address receiver = address(0xABCD);
        reserve.approve(address(vault), 20 ether);

        uint256 shares = vault.deposit(20 ether, receiver);

        assertEq(shares, 20 ether);
        assertEq(vault.balanceOf(receiver), 20 ether);
        assertEq(assetToken.balanceOf(receiver), 20 ether);
    }

    function testVaultMintAndRedeem() public {
        reserve.approve(address(vault), 30 ether);
        uint256 assets = vault.mint(30 ether, address(this));

        assertEq(assets, 30 ether);
        assertEq(assetToken.balanceOf(address(this)), 30 ether);

        uint256 redeemedAssets = vault.redeem(10 ether, address(this), address(this));
        assertEq(redeemedAssets, 10 ether);
        assertEq(vault.userDeposits(address(this)), 20 ether);
    }

    function testVaultWithdrawForReceiver() public {
        address receiver = address(0xCA11);
        reserve.approve(address(vault), 25 ether);
        vault.deposit(25 ether);

        uint256 receiverBefore = reserve.balanceOf(receiver);
        vault.withdraw(5 ether, receiver, address(this));

        assertEq(reserve.balanceOf(receiver), receiverBefore + 5 ether);
        assertEq(vault.userDeposits(address(this)), 20 ether);
    }
}

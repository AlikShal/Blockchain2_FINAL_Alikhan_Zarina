// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AssetVault.sol";
import "../src/AssetToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBackingAsset is ERC20 {
    constructor() ERC20("Backing Asset", "BACK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract AssetVaultTest is Test {
    AssetVault public vault;
    AssetToken public assetToken;
    MockBackingAsset public backingAsset;
    address public user1;

    function setUp() public {
        user1 = address(0x1);
        assetToken = new AssetToken();
        backingAsset = new MockBackingAsset();
        vault = new AssetVault(address(backingAsset), address(assetToken));

        assetToken.transferOwnership(address(vault));
        backingAsset.mint(user1, 10_000 * 10 ** 18);
    }

    function testDeposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        backingAsset.approve(address(vault), depositAmount);

        vm.prank(user1);
        vault.deposit(depositAmount);

        assertEq(vault.userDeposits(user1), depositAmount);
        assertEq(vault.totalDeposited(), depositAmount);
    }

    function testWithdraw() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        backingAsset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount);

        vm.prank(user1);
        vault.withdraw(500 * 10 ** 18);

        assertEq(vault.userDeposits(user1), 500 * 10 ** 18);
        assertEq(vault.totalDeposited(), 500 * 10 ** 18);
    }

    function testReserveRatio() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        backingAsset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount);

        assertEq(vault.getReserveRatio(), 100);
        assertTrue(vault.isHealthy());
    }

    function testDepositFails() public {
        vm.prank(user1);
        vm.expectRevert();
        vault.deposit(0);
    }

    function testWithdrawFails() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        vm.prank(user1);
        backingAsset.approve(address(vault), depositAmount);
        vm.prank(user1);
        vault.deposit(depositAmount);

        vm.prank(user1);
        vm.expectRevert();
        vault.withdraw(2000 * 10 ** 18);
    }
}

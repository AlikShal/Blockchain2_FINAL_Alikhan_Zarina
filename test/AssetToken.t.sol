// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "../src/AssetToken.sol";

contract AssetTokenTest is Test {
    AssetToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        token = new AssetToken();
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), 0);
        assertEq(token.name(), "Asset Token");
        assertEq(token.symbol(), "ASSET");
    }

    function testMint() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testMintOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 1000 * 10 ** 18);
    }

    function testMintExceedsMax() public {
        uint256 excessiveAmount = token.MAX_SUPPLY() + 1;
        vm.expectRevert();
        token.mint(user1, excessiveAmount);
    }

    function testBurn() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);

        vm.prank(user1);
        token.burn(500 * 10 ** 18);

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.totalSupply(), 500 * 10 ** 18);
    }

    function testBurnFrom() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(user2, amount);

        vm.prank(user2);
        token.burnFrom(user1, 500 * 10 ** 18);

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10 ** 18;
        token.mint(user1, amount);

        vm.prank(user1);
        assertTrue(token.transfer(user2, 500 * 10 ** 18));

        assertEq(token.balanceOf(user1), 500 * 10 ** 18);
        assertEq(token.balanceOf(user2), 500 * 10 ** 18);
    }

    function testRemainingSupply() public {
        uint256 initialRemaining = token.remainingSupply();
        assertEq(initialRemaining, token.MAX_SUPPLY());

        token.mint(user1, 1000 * 10 ** 18);
        assertEq(token.remainingSupply(), initialRemaining - 1000 * 10 ** 18);
    }

    function testRoleBasedMintAndBurnBacking() public {
        bytes32 minterRole = token.MINTER_ROLE();
        bytes32 burnerRole = token.BURNER_ROLE();
        token.grantRole(minterRole, user1);
        token.grantRole(burnerRole, user2);

        vm.prank(user1);
        token.mint(user1, 1000 * 10 ** 18);
        vm.prank(user2);
        token.burnBackingFrom(user1, 400 * 10 ** 18);

        assertEq(token.balanceOf(user1), 600 * 10 ** 18);
    }

    function testSupportsAccessControlInterface() public view {
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
    }
}

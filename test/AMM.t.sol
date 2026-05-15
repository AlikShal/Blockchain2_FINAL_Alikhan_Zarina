// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract AMMTest is Test {
    AMM public amm;
    MockToken public tokenA;
    MockToken public tokenB;
    address public user1;

    function setUp() public {
        user1 = address(0x1);
        tokenA = new MockToken("Token A", "TKNA");
        tokenB = new MockToken("Token B", "TKNB");
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(user1, 10_000 * 10 ** 18);
        tokenB.mint(user1, 10_000 * 10 ** 18);
    }

    function testAddLiquidity() public {
        uint256 amountA = 1000 * 10 ** 18;
        uint256 amountB = 1000 * 10 ** 18;

        vm.prank(user1);
        tokenA.approve(address(amm), amountA);
        vm.prank(user1);
        tokenB.approve(address(amm), amountB);

        vm.prank(user1);
        amm.addLiquidity(amountA, amountB);

        assertEq(amm.reserveA(), amountA);
        assertEq(amm.reserveB(), amountB);
        assertTrue(amm.balanceOf(user1) > 0);
    }

    function testSwapAForB() public {
        uint256 amountA = 1000 * 10 ** 18;
        uint256 amountB = 1000 * 10 ** 18;

        vm.prank(user1);
        tokenA.approve(address(amm), amountA);
        vm.prank(user1);
        tokenB.approve(address(amm), amountB);
        vm.prank(user1);
        amm.addLiquidity(amountA, amountB);

        uint256 swapAmount = 100 * 10 ** 18;
        vm.prank(user1);
        tokenA.approve(address(amm), swapAmount);

        uint256 tokenBBefore = tokenB.balanceOf(user1);
        vm.prank(user1);
        amm.swapAForB(swapAmount);
        uint256 tokenBAfter = tokenB.balanceOf(user1);

        assertTrue(tokenBAfter > tokenBBefore);
    }

    function testRemoveLiquidity() public {
        uint256 amountA = 1000 * 10 ** 18;
        uint256 amountB = 1000 * 10 ** 18;

        vm.prank(user1);
        tokenA.approve(address(amm), amountA);
        vm.prank(user1);
        tokenB.approve(address(amm), amountB);

        vm.prank(user1);
        amm.addLiquidity(amountA, amountB);

        uint256 lpBalance = amm.balanceOf(user1);
        vm.prank(user1);
        amm.removeLiquidity(lpBalance);

        assertEq(amm.balanceOf(user1), 0);
        assertEq(amm.reserveA(), 0);
        assertEq(amm.reserveB(), 0);
    }

    function testSwapBForA() public {
        uint256 amountA = 1000 * 10 ** 18;
        uint256 amountB = 1000 * 10 ** 18;

        vm.prank(user1);
        tokenA.approve(address(amm), amountA);
        vm.prank(user1);
        tokenB.approve(address(amm), amountB);
        vm.prank(user1);
        amm.addLiquidity(amountA, amountB);

        uint256 swapAmount = 100 * 10 ** 18;
        vm.prank(user1);
        tokenB.approve(address(amm), swapAmount);

        uint256 tokenABefore = tokenA.balanceOf(user1);
        vm.prank(user1);
        amm.swapBForA(swapAmount);
        uint256 tokenAAfter = tokenA.balanceOf(user1);

        assertTrue(tokenAAfter > tokenABefore);
    }
}

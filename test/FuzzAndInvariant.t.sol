// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/AMM.sol";
import "../src/AssetToken.sol";
import "../src/AssetVault.sol";
import "../src/Governance.sol";
import "../src/mocks/MockERC20.sol";

contract AMMHandler is Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    constructor(AMM amm_, MockERC20 tokenA_, MockERC20 tokenB_) {
        amm = amm_;
        tokenA = tokenA_;
        tokenB = tokenB_;
    }

    function swapA(uint256 amount) external {
        amount = bound(amount, 1, 5 ether);
        tokenA.mint(address(this), amount);
        tokenA.approve(address(amm), amount);
        try amm.swapAForB(amount, 0) {} catch {}
    }

    function swapB(uint256 amount) external {
        amount = bound(amount, 1, 5 ether);
        tokenB.mint(address(this), amount);
        tokenB.approve(address(amm), amount);
        try amm.swapBForA(amount, 0) {} catch {}
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        amountA = bound(amountA, 1 ether, 10 ether);
        amountB = bound(amountB, 1 ether, 10 ether);
        tokenA.mint(address(this), amountA);
        tokenB.mint(address(this), amountB);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        try amm.addLiquidity(amountA, amountB) {} catch {}
    }
}

contract FuzzAndInvariantTest is StdInvariant, Test {
    AMM public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    AssetToken public assetToken;
    AssetVault public vault;
    MockERC20 public reserve;
    AMMHandler public handler;

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKNA", 18);
        tokenB = new MockERC20("Token B", "TKNB", 18);
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.approve(address(amm), 1_000 ether);
        tokenB.approve(address(amm), 1_000 ether);
        amm.addLiquidity(1_000 ether, 1_000 ether);

        reserve = new MockERC20("Reserve", "RSV", 18);
        assetToken = new AssetToken();
        vault = new AssetVault(address(reserve), address(assetToken));
        assetToken.grantRole(assetToken.MINTER_ROLE(), address(vault));
        assetToken.grantRole(assetToken.BURNER_ROLE(), address(vault));

        handler = new AMMHandler(amm, tokenA, tokenB);
        targetContract(address(handler));
    }

    function testFuzzGetAmountOutPositive(uint256 amountIn) public view {
        amountIn = bound(amountIn, 1 ether, 1_000 ether);
        assertGt(amm.getAmountOut(amountIn, 1_000 ether, 1_000 ether), 0);
    }

    function testFuzzSwapAForBRespectsSlippage(uint256 amountIn, uint256 extra) public {
        amountIn = bound(amountIn, 1, 100 ether);
        uint256 quote = amm.getAmountOut(amountIn, amm.reserveA(), amm.reserveB());
        extra = bound(extra, 1, 100 ether);
        tokenA.approve(address(amm), amountIn);
        vm.expectRevert(bytes("AMM: slippage"));
        amm.swapAForB(amountIn, quote + extra);
    }

    function testFuzzSwapBForARespectsSlippage(uint256 amountIn, uint256 extra) public {
        amountIn = bound(amountIn, 1, 100 ether);
        uint256 quote = amm.getAmountOut(amountIn, amm.reserveB(), amm.reserveA());
        extra = bound(extra, 1, 100 ether);
        tokenB.approve(address(amm), amountIn);
        vm.expectRevert(bytes("AMM: slippage"));
        amm.swapBForA(amountIn, quote + extra);
    }

    function testFuzzAddLiquidityMintsLp(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 100 ether);
        amountB = bound(amountB, 1, 100 ether);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        uint256 beforeBalance = amm.balanceOf(address(this));
        amm.addLiquidity(amountA, amountB);
        assertGt(amm.balanceOf(address(this)), beforeBalance);
    }

    function testFuzzSqrtAssemblyMatchesSolidity(uint256 value) public view {
        value = bound(value, 0, type(uint128).max);
        assertEq(amm.sqrtAssembly(value), amm.sqrtSolidity(value));
    }

    function testFuzzVaultDeposit(uint256 amount) public {
        amount = bound(amount, 1, 1_000 ether);
        reserve.approve(address(vault), amount);
        vault.deposit(amount);
        assertEq(assetToken.balanceOf(address(this)), amount);
    }

    function testFuzzVaultWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 1_000 ether);
        reserve.approve(address(vault), amount);
        vault.deposit(amount);
        vault.withdraw(amount);
        assertEq(vault.userDeposits(address(this)), 0);
    }

    function testFuzzAssetTokenMint(uint256 amount) public {
        amount = bound(amount, 1, assetToken.MAX_SUPPLY());
        assetToken.mint(address(0xA11CE), amount);
        assertEq(assetToken.balanceOf(address(0xA11CE)), amount);
    }

    function testFuzzAssetTokenBurn(uint256 amount) public {
        amount = bound(amount, 1, 1_000 ether);
        assetToken.mint(address(this), amount);
        assetToken.burn(amount);
        assertEq(assetToken.balanceOf(address(this)), 0);
    }

    function testFuzzGovernanceVotingPowerMatchesDelegatedBalance(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);
        GovernanceToken governanceToken = new GovernanceToken();
        address voter = address(0x600D);

        assertTrue(governanceToken.transfer(voter, amount));
        vm.prank(voter);
        governanceToken.delegate(voter);

        assertEq(governanceToken.getVotes(voter), amount);
    }

    function testFuzzMin(uint256 a, uint256 b) public view {
        uint256 expected = a < b ? a : b;
        assertEq(amm.min(a, b), expected);
    }

    function invariant_ReservesMatchTokenBalances() public view {
        assertEq(tokenA.balanceOf(address(amm)), amm.reserveA());
        assertEq(tokenB.balanceOf(address(amm)), amm.reserveB());
    }

    function invariant_ConstantProductDoesNotDecreaseBelowInitial() public view {
        assertGe(amm.reserveA() * amm.reserveB(), (1_000 ether) * (1_000 ether));
    }

    function invariant_LpSupplyBackedByLiquidity() public view {
        assertGt(amm.totalSupply(), 0);
        assertGt(amm.reserveA(), 0);
        assertGt(amm.reserveB(), 0);
    }

    function invariant_VaultReserveRatioHealthyWhenDeposited() public view {
        if (vault.totalDeposited() > 0) {
            assertGe(vault.getReserveRatio(), vault.RESERVE_RATIO());
        }
    }

    function invariant_AssetTokenSupplyBelowCap() public view {
        assertLe(assetToken.totalSupply(), assetToken.MAX_SUPPLY());
    }

    function invariant_VaultTreasuryAccountingMatchesReserveBalance() public view {
        assertEq(reserve.balanceOf(address(vault)), vault.totalAssets());
    }

    function invariant_VaultSupplyConservation() public view {
        assertEq(vault.totalSupply(), vault.totalAssets());
        assertEq(assetToken.totalSupply(), vault.totalDeposited());
    }
}

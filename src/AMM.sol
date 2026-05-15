// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AMM is ERC20, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public constant FEE_BPS = 30;
    uint256 public constant FEE_PERCENT = FEE_BPS;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    event Swap(address indexed swapper, uint256 amountIn, uint256 amountOut, bool isTokenA);
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);

    constructor(address tokenA_, address tokenB_) ERC20("LP Token", "LP") {
        require(tokenA_ != address(0), "AMM: token A zero");
        require(tokenB_ != address(0), "AMM: token B zero");
        require(tokenA_ != tokenB_, "AMM: identical tokens");
        tokenA = IERC20(tokenA_);
        tokenB = IERC20(tokenB_);
    }

    // slither-disable-next-line reentrancy-no-eth
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "AMM: zero amount");

        if (reserveA == 0 && reserveB == 0) {
            liquidity = sqrtAssembly(amountA * amountB);
        } else {
            require(reserveA > 0 && reserveB > 0, "AMM: broken reserves");
            liquidity = min((amountA * totalSupply()) / reserveA, (amountB * totalSupply()) / reserveB);
        }

        require(liquidity > 0, "AMM: zero liquidity");
        tokenA.safeTransferFrom(_msgSender(), address(this), amountA);
        tokenB.safeTransferFrom(_msgSender(), address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;
        // slither-disable-next-line reentrancy-benign
        _mint(_msgSender(), liquidity);

        emit LiquidityAdded(_msgSender(), amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 lpTokens) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(lpTokens > 0 && lpTokens <= balanceOf(_msgSender()), "AMM: invalid LP");

        uint256 supply = totalSupply();
        amountA = (lpTokens * reserveA) / supply;
        amountB = (lpTokens * reserveB) / supply;
        require(amountA > 0 && amountB > 0, "AMM: zero output");

        _burn(_msgSender(), lpTokens);
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.safeTransfer(_msgSender(), amountA);
        tokenB.safeTransfer(_msgSender(), amountB);

        emit LiquidityRemoved(_msgSender(), amountA, amountB, lpTokens);
    }

    function swapAForB(uint256 amountAIn) external returns (uint256 amountBOut) {
        amountBOut = swapAForB(amountAIn, 0);
    }

    function swapAForB(uint256 amountAIn, uint256 minAmountBOut) public nonReentrant returns (uint256 amountBOut) {
        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut >= minAmountBOut, "AMM: slippage");

        reserveA += amountAIn;
        reserveB -= amountBOut;

        tokenA.safeTransferFrom(_msgSender(), address(this), amountAIn);
        tokenB.safeTransfer(_msgSender(), amountBOut);

        emit Swap(_msgSender(), amountAIn, amountBOut, true);
    }

    function swapBForA(uint256 amountBIn) external returns (uint256 amountAOut) {
        amountAOut = swapBForA(amountBIn, 0);
    }

    function swapBForA(uint256 amountBIn, uint256 minAmountAOut) public nonReentrant returns (uint256 amountAOut) {
        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut >= minAmountAOut, "AMM: slippage");

        reserveB += amountBIn;
        reserveA -= amountAOut;

        tokenB.safeTransferFrom(_msgSender(), address(this), amountBIn);
        tokenA.safeTransfer(_msgSender(), amountAOut);

        emit Swap(_msgSender(), amountBIn, amountAOut, false);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "AMM: zero input");
        require(reserveIn > 0 && reserveOut > 0, "AMM: no liquidity");
        uint256 amountInWithFee = amountIn * (BPS_DENOMINATOR - FEE_BPS);
        return (amountInWithFee * reserveOut) / (reserveIn * BPS_DENOMINATOR + amountInWithFee);
    }

    function sqrtSolidity(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function sqrtAssembly(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;
        // slither-disable-next-line assembly
        assembly {
            y := x
            let z := div(add(x, 1), 2)
            for {} lt(z, y) {} {
                y := z
                z := div(add(div(x, z), z), 2)
            }
        }
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }
}

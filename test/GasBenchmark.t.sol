// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/mocks/MockERC20.sol";

contract GasBenchmarkTest is Test {
    AMM public amm;

    function setUp() public {
        MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18);
        MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18);
        amm = new AMM(address(tokenA), address(tokenB));
    }

    function testGasBenchmarkSqrtAssemblyVsSolidity() public {
        uint256 value = 123_456_789 ether;

        uint256 gasBeforeSolidity = gasleft();
        uint256 solidityResult = amm.sqrtSolidity(value);
        uint256 solidityGas = gasBeforeSolidity - gasleft();

        uint256 gasBeforeAssembly = gasleft();
        uint256 assemblyResult = amm.sqrtAssembly(value);
        uint256 assemblyGas = gasBeforeAssembly - gasleft();

        emit log_named_uint("sqrtSolidity gas", solidityGas);
        emit log_named_uint("sqrtAssembly gas", assemblyGas);

        assertEq(assemblyResult, solidityResult);
        assertLe(assemblyGas, solidityGas);
    }
}

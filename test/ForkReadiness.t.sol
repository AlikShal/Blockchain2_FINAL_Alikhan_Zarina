// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IUniswapV2RouterLike {
    function factory() external view returns (address);
    function WETH() external view returns (address);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
}

contract ForkReadinessTest is Test {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant MAINNET_UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function _mainnetRpc() internal view returns (string memory) {
        return vm.envOr("MAINNET_RPC_URL", string(""));
    }

    function _hasUsableRpc(string memory rpc) internal pure returns (bool) {
        bytes32 rpcHash = keccak256(bytes(rpc));
        return bytes(rpc).length != 0 && rpcHash != keccak256(bytes("ethereum-mainnet-rpc"))
            && rpcHash != keccak256(bytes("https://ethereum-mainnet-rpc"));
    }

    function testForkMainnetUsdcHasCode() public {
        string memory rpc = _mainnetRpc();
        if (!_hasUsableRpc(rpc)) return;
        vm.createSelectFork(rpc);
        assertGt(MAINNET_USDC.code.length, 0);
    }

    function testForkMainnetChainlinkFeedHasCode() public {
        string memory rpc = _mainnetRpc();
        if (!_hasUsableRpc(rpc)) return;
        vm.createSelectFork(rpc);
        assertGt(MAINNET_CHAINLINK_ETH_USD.code.length, 0);
    }

    function testForkMainnetBlockNumberIsNonZero() public {
        string memory rpc = _mainnetRpc();
        if (!_hasUsableRpc(rpc)) return;
        vm.createSelectFork(rpc);
        assertGt(block.number, 0);
    }

    function testForkMainnetUniswapRouterInteraction() public {
        string memory rpc = _mainnetRpc();
        if (!_hasUsableRpc(rpc)) return;
        vm.createSelectFork(rpc);

        IUniswapV2RouterLike router = IUniswapV2RouterLike(MAINNET_UNISWAP_V2_ROUTER);
        address factory = router.factory();
        address weth = router.WETH();

        assertGt(MAINNET_UNISWAP_V2_ROUTER.code.length, 0);
        assertGt(factory.code.length, 0);
        assertGt(weth.code.length, 0);
    }
}

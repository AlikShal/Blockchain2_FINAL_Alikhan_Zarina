// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AssetRegistry.sol";

contract AssetRegistryV2 is AssetRegistry {
    event RegistryV2Ping(address indexed caller);

    function version() external pure returns (string memory) {
        return "2.0.0";
    }

    function pingV2() external {
        emit RegistryV2Ping(msg.sender);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

contract VerifyScript is Script {
    function run() external {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("Verifying contracts for proxy:", proxyAddress);
        console.log("Use this command:");
        console.log("forge verify-contract <impl_address> src/MultiVault.sol:MultiVault --chain-id 8453");
    }
}

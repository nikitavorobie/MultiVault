// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

interface IOwnable {
    function owner() external view returns (address);
}

contract CheckOwnerScript is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        console.log("=== Checking Owner ===");
        console.log("Proxy address:", proxyAddress);

        try IOwnable(proxyAddress).owner() returns (address owner) {
            console.log("Current owner:", owner);
            console.log("\nDeployer address from PRIVATE_KEY:");

            // Get deployer address from private key
            uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
            address deployer = vm.addr(deployerPrivateKey);
            console.log("Deployer:", deployer);

            if (owner == deployer) {
                console.log("\n[OK] Deployer IS the owner - upgrade should work!");
            } else {
                console.log("\n[ERROR] Deployer is NOT the owner!");
                console.log("You need to use the private key of:", owner);
            }
        } catch {
            console.log("[ERROR] Failed to call owner() - contract might use AccessControl already");
        }
    }
}

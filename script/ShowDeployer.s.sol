// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

contract ShowDeployerScript is Script {
    function run() external view {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deployer Address ===");
        console.log("Address:", deployer);
        console.log("\nThis address should be the owner of the proxy contract");
        console.log("If not, you need to either:");
        console.log("1. Use the correct private key in GitHub Secrets");
        console.log("2. Or transfer ownership to this address first");
    }
}

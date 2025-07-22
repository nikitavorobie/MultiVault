// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        MultiVault newImplementation = new MultiVault();
        console.log("New implementation deployed at:", address(newImplementation));

        MultiVault proxy = MultiVault(payable(proxyAddress));
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("Proxy upgraded successfully");
        console.log("Proxy address:", proxyAddress);
        console.log("New implementation:", address(newImplementation));

        vm.stopBroadcast();
    }
}

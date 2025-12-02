// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MultiVault vaultImpl = new MultiVault();
        console.log("MultiVault implementation deployed at:", address(vaultImpl));

        bytes memory initData = abi.encodeWithSelector(
            MultiVault.initialize.selector
        );

        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultImpl),
            initData
        );
        console.log("MultiVault proxy deployed at:", address(vaultProxy));

        PayoutExecutor payoutImpl = new PayoutExecutor();
        console.log("PayoutExecutor implementation deployed at:", address(payoutImpl));

        bytes memory payoutInitData = abi.encodeWithSelector(
            PayoutExecutor.initialize.selector,
            address(vaultProxy)
        );

        ERC1967Proxy payoutProxy = new ERC1967Proxy(
            address(payoutImpl),
            payoutInitData
        );
        console.log("PayoutExecutor proxy deployed at:", address(payoutProxy));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Network: Base");
        console.log("Deployer:", deployer);
        console.log("MultiVault Proxy:", address(vaultProxy));
        console.log("PayoutExecutor Proxy:", address(payoutProxy));
    }
}

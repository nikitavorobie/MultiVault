// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Interface for UUPS upgradeable proxies
interface IUUPSProxy {
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
}

contract UpgradeRolesScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("MULTIVAULT_PROXY");
        address executorProxyAddress = vm.envAddress("EXECUTOR_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new MultiVault implementation
        console.log("Deploying new MultiVault implementation...");
        MultiVault newVaultImpl = new MultiVault();
        console.log("New MultiVault implementation:", address(newVaultImpl));

        // Deploy new PayoutExecutor implementation
        console.log("Deploying new PayoutExecutor implementation...");
        PayoutExecutor newExecutorImpl = new PayoutExecutor();
        console.log("New PayoutExecutor implementation:", address(newExecutorImpl));

        // Prepare initializeV2 call to grant DEFAULT_ADMIN_ROLE to deployer
        bytes memory initData = abi.encodeWithSignature("initializeV2()");

        // Upgrade MultiVault proxy using interface (avoids ABI conflicts)
        console.log("Upgrading MultiVault proxy...");
        IUUPSProxy vaultProxy = IUUPSProxy(proxyAddress);
        vaultProxy.upgradeToAndCall(address(newVaultImpl), initData);
        console.log("MultiVault proxy upgraded");

        // Upgrade PayoutExecutor proxy using interface (avoids ABI conflicts)
        console.log("Upgrading PayoutExecutor proxy...");
        IUUPSProxy executorProxy = IUUPSProxy(executorProxyAddress);
        executorProxy.upgradeToAndCall(address(newExecutorImpl), initData);
        console.log("PayoutExecutor proxy upgraded");

        vm.stopBroadcast();

        console.log("\n=== Upgrade Complete ===");
        console.log("MultiVault Proxy:", proxyAddress);
        console.log("MultiVault Implementation:", address(newVaultImpl));
        console.log("PayoutExecutor Proxy:", executorProxyAddress);
        console.log("PayoutExecutor Implementation:", address(newExecutorImpl));
        console.log("\nNote: Role reconfiguration should be done separately via governance");
    }
}

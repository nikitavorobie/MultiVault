// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

interface IAccessControl {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
}

interface IOwnable {
    function owner() external view returns (address);
}

interface IERC1967 {
    function implementation() external view returns (address);
}

contract CheckCurrentStateScript is Script {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Checking Contract State ===");
        console.log("Proxy address:", proxyAddress);
        console.log("Deployer address:", deployer);
        console.log("");

        // Try to get implementation address
        try IERC1967(proxyAddress).implementation() returns (address impl) {
            console.log("Current implementation:", impl);
        } catch {
            console.log("Could not get implementation address");
        }

        console.log("");
        console.log("=== Checking Ownable ===");
        // Check Ownable
        try IOwnable(proxyAddress).owner() returns (address owner) {
            console.log("Owner (Ownable):", owner);
            if (owner == address(0)) {
                console.log("[WARNING] Owner is address(0) - contract might be unmanaged!");
            } else if (owner == deployer) {
                console.log("[OK] Deployer is the owner");
            } else {
                console.log("[INFO] Owner is different from deployer");
            }
        } catch {
            console.log("owner() call failed - contract might not use Ownable");
        }

        console.log("");
        console.log("=== Checking AccessControl ===");
        // Check AccessControl
        try IAccessControl(proxyAddress).hasRole(DEFAULT_ADMIN_ROLE, deployer) returns (bool hasRole) {
            console.log("Contract uses AccessControl!");
            console.log("Deployer has DEFAULT_ADMIN_ROLE:", hasRole);

            if (hasRole) {
                console.log("[OK] Deployer can upgrade the contract");
            } else {
                console.log("[ERROR] Deployer does NOT have DEFAULT_ADMIN_ROLE");
                console.log("Need to find who has the admin role");
            }
        } catch {
            console.log("AccessControl check failed - contract might not use AccessControl");
        }

        console.log("");
        console.log("=== Conclusion ===");
        console.log("If owner() returns address(0) AND AccessControl fails,");
        console.log("the contract is UNMANAGEABLE and needs redeployment.");
    }
}

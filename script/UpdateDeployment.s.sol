// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MultiVault.sol";

contract UpdateDeploymentScript is Script {
    function run() external view {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        MultiVault proxy = MultiVault(payable(proxyAddress));

        console.log("=== Deployment Info ===");
        console.log("Proxy:", proxyAddress);
        console.log("Vault Count:", proxy.getVaultCount());
        console.log("Proposal Count:", proxy.getProposalCount());
        console.log("Proposal Expiration Period:", proxy.proposalExpirationPeriod());
    }
}

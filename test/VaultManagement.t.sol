// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultManagementTest is Test {
    MultiVault public vault;
    MultiVault public implementation;

    address public owner = address(1);
    address public signer1 = address(2);
    address public signer2 = address(3);
    address public signer3 = address(4);

    function setUp() public {
        vm.startPrank(owner);

        implementation = new MultiVault();

        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 100;
        weights[1] = 100;

        bytes memory initData = abi.encodeWithSelector(
            MultiVault.initialize.selector,
            signers,
            weights,
            150
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        vault = MultiVault(payable(address(proxy)));
        vm.stopPrank();
    }

    function testCreateVault() public {
        vm.prank(owner);
        uint256 vaultId = vault.createVault("Treasury", "ipfs://Qm...");

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.id, 0);
        assertEq(info.name, "Treasury");
        assertEq(info.metadataRef, "ipfs://Qm...");
        assertEq(info.threshold, 0);
        assertEq(info.totalWeight, 0);
        assertEq(info.signerCount, 0);
        assertTrue(info.active);
    }

    function testCreateMultipleVaults() public {
        vm.startPrank(owner);

        uint256 vault1 = vault.createVault("DAO Treasury", "ipfs://dao");
        uint256 vault2 = vault.createVault("Dev Fund", "ipfs://dev");
        uint256 vault3 = vault.createVault("Marketing", "ipfs://marketing");

        assertEq(vault1, 0);
        assertEq(vault2, 1);
        assertEq(vault3, 2);

        IMultiVault.VaultInfo memory v1 = vault.getVaultInfo(vault1);
        IMultiVault.VaultInfo memory v2 = vault.getVaultInfo(vault2);
        IMultiVault.VaultInfo memory v3 = vault.getVaultInfo(vault3);

        assertEq(v1.name, "DAO Treasury");
        assertEq(v2.name, "Dev Fund");
        assertEq(v3.name, "Marketing");

        vm.stopPrank();
    }

    function testCannotCreateVaultWithEmptyName() public {
        vm.prank(owner);
        vm.expectRevert(MultiVault.InvalidVaultName.selector);
        vault.createVault("", "ipfs://test");
    }

    function testAddSignerToVault() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);

        IMultiVault.Signer memory s = vault.getSignerInfo(vaultId, signer1);
        assertEq(s.addr, signer1);
        assertEq(s.weight, 100);
        assertTrue(s.active);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.totalWeight, 100);
        assertEq(info.signerCount, 1);

        vm.stopPrank();
    }

    function testAddMultipleSignersToVault() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Multi-Sig", "ipfs://ms");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 150);
        vault.addSigner(vaultId, signer3, 200);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.totalWeight, 450);
        assertEq(info.signerCount, 3);

        vm.stopPrank();
    }

    function testCannotAddDuplicateSigner() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.SignerAlreadyExists.selector);
        vault.addSigner(vaultId, signer1, 100);

        vm.stopPrank();
    }

    function testCannotAddSignerWithZeroWeight() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");

        vm.expectRevert(MultiVault.InvalidWeight.selector);
        vault.addSigner(vaultId, signer1, 0);

        vm.stopPrank();
    }

    function testRemoveSignerFromVault() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 150);

        vault.removeSigner(vaultId, signer1);

        IMultiVault.Signer memory s = vault.getSignerInfo(vaultId, signer1);
        assertFalse(s.active);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.totalWeight, 150);
        assertEq(info.signerCount, 1);

        vm.stopPrank();
    }

    function testCannotRemoveLastSigner() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.CannotRemoveLastSigner.selector);
        vault.removeSigner(vaultId, signer1);

        vm.stopPrank();
    }

    function testSetThreshold() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 150);

        vault.setThreshold(vaultId, 200);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.threshold, 200);

        vm.stopPrank();
    }

    function testCannotSetThresholdAboveTotalWeight() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.InvalidThreshold.selector);
        vault.setThreshold(vaultId, 150);

        vm.stopPrank();
    }

    function testCannotSetZeroThreshold() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.InvalidThreshold.selector);
        vault.setThreshold(vaultId, 0);

        vm.stopPrank();
    }

    function testVaultIsolation() public {
        vm.startPrank(owner);

        uint256 vault1 = vault.createVault("Vault1", "ipfs://1");
        uint256 vault2 = vault.createVault("Vault2", "ipfs://2");

        vault.addSigner(vault1, signer1, 100);
        vault.addSigner(vault2, signer2, 200);

        IMultiVault.Signer memory s1v1 = vault.getSignerInfo(vault1, signer1);
        IMultiVault.Signer memory s2v1 = vault.getSignerInfo(vault1, signer2);
        IMultiVault.Signer memory s1v2 = vault.getSignerInfo(vault2, signer1);
        IMultiVault.Signer memory s2v2 = vault.getSignerInfo(vault2, signer2);

        assertTrue(s1v1.active);
        assertFalse(s2v1.active);
        assertFalse(s1v2.active);
        assertTrue(s2v2.active);

        vm.stopPrank();
    }

    function testOnlyOwnerCanCreateVault() public {
        vm.prank(signer1);
        vm.expectRevert();
        vault.createVault("Unauthorized", "ipfs://test");
    }

    function testOnlyOwnerCanAddSigner() public {
        vm.prank(owner);
        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");

        vm.prank(signer1);
        vm.expectRevert();
        vault.addSigner(vaultId, signer2, 100);
    }

    function testOnlyOwnerCanSetThreshold() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Treasury", "ipfs://meta");
        vault.addSigner(vaultId, signer1, 100);
        vm.stopPrank();

        vm.prank(signer1);
        vm.expectRevert();
        vault.setThreshold(vaultId, 50);
    }
}

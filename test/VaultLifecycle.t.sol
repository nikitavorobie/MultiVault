// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultLifecycleTest is Test {
    MultiVault public vault;
    MultiVault public implementation;

    address public owner = address(1);
    address public signer1 = address(2);
    address public signer2 = address(3);
    address public signer3 = address(4);
    address public recipient = address(5);

    function setUp() public {
        vm.startPrank(owner);

        implementation = new MultiVault();

        bytes memory initData = abi.encodeWithSelector(
            MultiVault.initialize.selector
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        vault = MultiVault(payable(address(proxy)));
        vm.deal(address(vault), 100 ether);
        vm.stopPrank();
    }

    function testVaultCreation() public {
        vm.prank(owner);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://QmTest");

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.id, 0);
        assertEq(info.name, "Test Vault");
        assertEq(info.metadataRef, "ipfs://QmTest");
        assertEq(info.threshold, 0);
        assertEq(info.totalWeight, 0);
        assertEq(info.signerCount, 0);
        assertTrue(info.active);
    }

    function testVaultArchival() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Archive Test", "ipfs://archive");
        vault.addSigner(vaultId, signer1, 100);
        vault.setThreshold(vaultId, 100);

        vault.archiveVault(vaultId);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertFalse(info.active);

        vm.stopPrank();
    }

    function testCannotArchiveAlreadyArchivedVault() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.archiveVault(vaultId);

        vm.expectRevert(MultiVault.VaultAlreadyArchived.selector);
        vault.archiveVault(vaultId);

        vm.stopPrank();
    }

    function testCannotOperateOnArchivedVault() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.archiveVault(vaultId);

        vm.expectRevert(MultiVault.VaultNotFound.selector);
        vault.addSigner(vaultId, signer1, 100);

        vm.stopPrank();
    }

    function testUpdateSignerWeight() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 200);

        IMultiVault.VaultInfo memory infoBefore = vault.getVaultInfo(vaultId);
        assertEq(infoBefore.totalWeight, 300);

        vault.updateSignerWeight(vaultId, signer1, 150);

        IMultiVault.Signer memory s = vault.getSignerInfo(vaultId, signer1);
        assertEq(s.weight, 150);

        IMultiVault.VaultInfo memory infoAfter = vault.getVaultInfo(vaultId);
        assertEq(infoAfter.totalWeight, 350);

        vm.stopPrank();
    }

    function testCannotUpdateWeightToZero() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.InvalidWeight.selector);
        vault.updateSignerWeight(vaultId, signer1, 0);

        vm.stopPrank();
    }

    function testChangeThresholdWithActiveProposal() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vault.setThreshold(vaultId, 150);

        vm.stopPrank();

        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(vaultId, recipient, 1 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.prank(owner);
        vault.setThreshold(vaultId, 100);

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function testRemoveSignerWhoVotedOnActiveProposal() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vault.addSigner(vaultId, signer3, 100);
        vault.setThreshold(vaultId, 250);

        vm.stopPrank();

        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(vaultId, recipient, 1 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.prank(owner);
        vault.removeSigner(vaultId, signer1);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertEq(proposal.approvalWeight, 100);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.totalWeight, 200);
        assertEq(info.threshold, 250);

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        vm.expectRevert(MultiVault.InsufficientApprovals.selector);
        vm.prank(signer2);
        vault.executeProposal(proposalId);
    }

    function testAddSignerAfterVaultCreation() public {
        vm.startPrank(owner);

        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.setThreshold(vaultId, 100);

        vm.stopPrank();

        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(vaultId, recipient, 1 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.startPrank(owner);
        vault.addSigner(vaultId, signer2, 100);
        vault.setThreshold(vaultId, 150);
        vm.stopPrank();

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function testMultipleVaultsIndependence() public {
        vm.startPrank(owner);

        uint256 vault1 = vault.createVault("Vault 1", "ipfs://v1");
        uint256 vault2 = vault.createVault("Vault 2", "ipfs://v2");

        vault.addSigner(vault1, signer1, 100);
        vault.addSigner(vault2, signer2, 200);

        vault.setThreshold(vault1, 100);
        vault.setThreshold(vault2, 200);

        vm.stopPrank();

        vm.prank(signer1);
        uint256 proposal1 = vault.createProposal(vault1, recipient, 1 ether, address(0), "");

        vm.prank(signer2);
        uint256 proposal2 = vault.createProposal(vault2, recipient, 2 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposal1);

        vm.prank(signer2);
        vault.approveProposal(proposal2);

        vm.prank(signer1);
        vault.executeProposal(proposal1);

        vm.prank(signer2);
        vault.executeProposal(proposal2);

        IMultiVault.Proposal memory p1 = vault.getProposal(proposal1);
        IMultiVault.Proposal memory p2 = vault.getProposal(proposal2);

        assertTrue(p1.executed);
        assertTrue(p2.executed);
        assertEq(p1.amount, 1 ether);
        assertEq(p2.amount, 2 ether);
    }

    function testVaultCountIncrementsCorrectly() public {
        vm.startPrank(owner);

        assertEq(vault.getVaultCount(), 0);

        vault.createVault("V1", "ipfs://v1");
        assertEq(vault.getVaultCount(), 1);

        vault.createVault("V2", "ipfs://v2");
        assertEq(vault.getVaultCount(), 2);

        vault.createVault("V3", "ipfs://v3");
        assertEq(vault.getVaultCount(), 3);

        vm.stopPrank();
    }

    function testArchiveVaultDoesNotAffectOtherVaults() public {
        vm.startPrank(owner);

        uint256 vault1 = vault.createVault("V1", "ipfs://v1");
        uint256 vault2 = vault.createVault("V2", "ipfs://v2");

        vault.archiveVault(vault1);

        IMultiVault.VaultInfo memory info1 = vault.getVaultInfo(vault1);
        IMultiVault.VaultInfo memory info2 = vault.getVaultInfo(vault2);

        assertFalse(info1.active);
        assertTrue(info2.active);

        vm.stopPrank();
    }
}

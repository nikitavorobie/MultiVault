// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConfigurationChangesTest is Test {
    MultiVault public vault;
    MultiVault public implementation;

    address public owner = address(1);
    address public signer1 = address(2);
    address public signer2 = address(3);
    address public signer3 = address(4);
    address public signer4 = address(5);
    address public recipient = address(6);

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

    function testThresholdChangeDoesNotInvalidateExistingApprovals() public {
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

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        IMultiVault.Proposal memory proposalBefore = vault.getProposal(proposalId);
        assertEq(proposalBefore.approvalWeight, 200);

        vm.prank(owner);
        vault.setThreshold(vaultId, 200);

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        IMultiVault.Proposal memory proposalAfter = vault.getProposal(proposalId);
        assertTrue(proposalAfter.executed);
    }

    function testWeightChangeAffectsTotalWeightImmediately() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 200);
        vault.addSigner(vaultId, signer3, 300);

        IMultiVault.VaultInfo memory infoBefore = vault.getVaultInfo(vaultId);
        assertEq(infoBefore.totalWeight, 600);

        vault.updateSignerWeight(vaultId, signer2, 50);

        IMultiVault.VaultInfo memory infoAfter = vault.getVaultInfo(vaultId);
        assertEq(infoAfter.totalWeight, 450);

        vm.stopPrank();
    }

    function testWeightChangeDoesNotAffectExistingApprovals() public {
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

        IMultiVault.Proposal memory proposalBefore = vault.getProposal(proposalId);
        assertEq(proposalBefore.approvalWeight, 100);

        vm.prank(owner);
        vault.updateSignerWeight(vaultId, signer1, 200);

        IMultiVault.Proposal memory proposalAfter = vault.getProposal(proposalId);
        assertEq(proposalAfter.approvalWeight, 100);
    }

    function testCannotSetThresholdHigherThanTotalWeight() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);

        vm.expectRevert(MultiVault.InvalidThreshold.selector);
        vault.setThreshold(vaultId, 250);

        vm.stopPrank();
    }

    function testThresholdBecomesInvalidAfterWeightReduction() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vault.addSigner(vaultId, signer3, 100);
        vault.setThreshold(vaultId, 250);

        vault.updateSignerWeight(vaultId, signer3, 50);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.totalWeight, 250);
        assertEq(info.threshold, 250);

        vm.stopPrank();
    }

    function testAddMultipleSignersInSequence() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");

        vault.addSigner(vaultId, signer1, 100);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 100);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 1);

        vault.addSigner(vaultId, signer2, 150);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 250);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 2);

        vault.addSigner(vaultId, signer3, 200);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 450);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 3);

        vault.addSigner(vaultId, signer4, 50);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 500);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 4);

        vm.stopPrank();
    }

    function testRemoveMultipleSignersInSequence() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 150);
        vault.addSigner(vaultId, signer3, 200);
        vault.addSigner(vaultId, signer4, 50);

        vault.removeSigner(vaultId, signer4);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 450);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 3);

        vault.removeSigner(vaultId, signer2);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 300);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 2);

        vault.removeSigner(vaultId, signer1);
        assertEq(vault.getVaultInfo(vaultId).totalWeight, 200);
        assertEq(vault.getVaultInfo(vaultId).signerCount, 1);

        vm.stopPrank();
    }

    function testCannotRemoveNonExistentSigner() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.SignerNotFound.selector);
        vault.removeSigner(vaultId, signer2);

        vm.stopPrank();
    }

    function testCannotUpdateWeightOfNonExistentSigner() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.SignerNotFound.selector);
        vault.updateSignerWeight(vaultId, signer2, 150);

        vm.stopPrank();
    }

    function testRemovedSignerCannotApproveProposals() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vault.setThreshold(vaultId, 100);
        vm.stopPrank();

        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(vaultId, recipient, 1 ether, address(0), "");

        vm.prank(owner);
        vault.removeSigner(vaultId, signer1);

        vm.expectRevert(MultiVault.InvalidSigner.selector);
        vm.prank(signer1);
        vault.approveProposal(proposalId);
    }

    function testSignerCannotBeAddedTwice() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectRevert(MultiVault.SignerAlreadyExists.selector);
        vault.addSigner(vaultId, signer1, 150);

        vm.stopPrank();
    }

    function testWeightUpdateEmitsCorrectEvent() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");
        vault.addSigner(vaultId, signer1, 100);

        vm.expectEmit(true, true, false, true);
        emit IMultiVault.VaultSignerWeightUpdated(vaultId, signer1, 100, 150);
        vault.updateSignerWeight(vaultId, signer1, 150);

        vm.stopPrank();
    }

    function testArchiveVaultEmitsCorrectEvent() public {
        vm.startPrank(owner);
        uint256 vaultId = vault.createVault("Test", "ipfs://test");

        vm.expectEmit(true, false, false, false);
        emit IMultiVault.VaultArchived(vaultId);
        vault.archiveVault(vaultId);

        vm.stopPrank();
    }

    function testConfigurationChangesAcrossMultipleVaults() public {
        vm.startPrank(owner);
        uint256 vault1 = vault.createVault("V1", "ipfs://v1");
        uint256 vault2 = vault.createVault("V2", "ipfs://v2");

        vault.addSigner(vault1, signer1, 100);
        vault.addSigner(vault1, signer2, 50);
        vault.addSigner(vault2, signer1, 200);

        vault.updateSignerWeight(vault1, signer1, 150);

        assertEq(vault.getSignerInfo(vault1, signer1).weight, 150);
        assertEq(vault.getSignerInfo(vault2, signer1).weight, 200);

        vault.removeSigner(vault1, signer1);

        assertFalse(vault.getSignerInfo(vault1, signer1).active);
        assertTrue(vault.getSignerInfo(vault2, signer1).active);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MultiVaultTest is Test {
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

        address[] memory signers = new address[](3);
        signers[0] = signer1;
        signers[1] = signer2;
        signers[2] = signer3;

        uint256[] memory weights = new uint256[](3);
        weights[0] = 100;
        weights[1] = 150;
        weights[2] = 200;

        bytes memory initData = abi.encodeWithSelector(
            MultiVault.initialize.selector,
            signers,
            weights,
            300
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        vault = MultiVault(payable(address(proxy)));

        vm.deal(address(vault), 100 ether);
        vm.stopPrank();
    }

    function testInitialization() public view {
        assertEq(vault.getTotalWeight(), 450);
        assertEq(vault.getThreshold(), 300);

        IMultiVault.Signer memory s1 = vault.getSigner(signer1);
        assertEq(s1.weight, 100);
        assertTrue(s1.active);
    }

    function testAddSigner() public {
        vm.prank(owner);
        vault.addSigner(address(6), 50);

        assertEq(vault.getTotalWeight(), 500);

        IMultiVault.Signer memory newSigner = vault.getSigner(address(6));
        assertEq(newSigner.weight, 50);
        assertTrue(newSigner.active);
    }

    function testRemoveSigner() public {
        vm.prank(owner);
        vault.removeSigner(signer1);

        assertEq(vault.getTotalWeight(), 350);

        IMultiVault.Signer memory s1 = vault.getSigner(signer1);
        assertFalse(s1.active);
    }

    function testCreateProposal() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, "");

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertEq(proposal.recipient, recipient);
        assertEq(proposal.amount, 1 ether);
        assertEq(proposal.approvalWeight, 0);
        assertFalse(proposal.executed);
    }

    function testApproveProposal() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertEq(proposal.approvalWeight, 100);
    }

    function testExecuteProposal() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, "");

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        vm.prank(signer3);
        vault.approveProposal(proposalId);

        uint256 balanceBefore = recipient.balance;

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        assertEq(recipient.balance, balanceBefore + 1 ether);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function testCannotExecuteWithoutThreshold() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.prank(signer1);
        vm.expectRevert(MultiVault.InsufficientApprovals.selector);
        vault.executeProposal(proposalId);
    }

    function testCancelProposal() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, "");

        vm.prank(owner);
        vault.cancelProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertTrue(proposal.cancelled);
    }
}

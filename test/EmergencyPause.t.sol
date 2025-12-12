// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract EmergencyPauseTest is Test {
    MultiVault public vault;
    PayoutExecutor public executor;

    address public admin;
    address public pauser;
    address public vaultAdmin;
    address public unauthorized;

    function setUp() public {
        pauser = makeAddr("pauser");
        vaultAdmin = makeAddr("vaultAdmin");
        unauthorized = makeAddr("unauthorized");

        MultiVault vaultImpl = new MultiVault();
        bytes memory vaultInitData = abi.encodeCall(MultiVault.initialize, ());
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = MultiVault(payable(address(vaultProxy)));

        PayoutExecutor executorImpl = new PayoutExecutor();
        bytes memory executorInitData = abi.encodeCall(PayoutExecutor.initialize, (address(vault)));
        ERC1967Proxy executorProxy = new ERC1967Proxy(address(executorImpl), executorInitData);
        executor = PayoutExecutor(payable(address(executorProxy)));

        admin = address(this);

        vault.grantRole(vault.PAUSER_ROLE(), pauser);
        executor.grantRole(executor.PAUSER_ROLE(), pauser);
    }

    // ============================================
    // Test: Pause Authorization
    // ============================================

    function testGlobalAdminCanPause() public {
        vm.prank(admin);
        vault.pause();

        assertTrue(vault.paused());
    }

    function testPauserCanPause() public {
        vm.prank(pauser);
        vault.pause();

        assertTrue(vault.paused());
    }

    function testUnauthorizedCannotPause() public {
        vm.prank(unauthorized);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.pause();
    }

    function testGlobalAdminCanUnpause() public {
        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function testPauserCanUnpause() public {
        vm.prank(pauser);
        vault.pause();

        vm.prank(pauser);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function testUnauthorizedCannotUnpause() public {
        vm.prank(pauser);
        vault.pause();

        vm.prank(unauthorized);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.unpause();
    }

    // ============================================
    // Test: Pause Effects on MultiVault
    // ============================================

    function testCannotCreateVaultWhenPaused() public {
        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.createVault("Test Vault", "ipfs://test");
    }

    function testCannotAddSignerWhenPaused() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.addSigner(vaultId, makeAddr("signer1"), 100);
    }

    function testCannotRemoveSignerWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer1 = makeAddr("signer1");
        address signer2 = makeAddr("signer2");
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vm.stopPrank();

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.removeSigner(vaultId, signer1);
    }

    function testCannotSetThresholdWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        vault.addSigner(vaultId, makeAddr("signer1"), 100);
        vm.stopPrank();

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.setThreshold(vaultId, 50);
    }

    function testCannotUpdateSignerWeightWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer1 = makeAddr("signer1");
        vault.addSigner(vaultId, signer1, 100);
        vm.stopPrank();

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.updateSignerWeight(vaultId, signer1, 200);
    }

    function testCannotArchiveVaultWhenPaused() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.archiveVault(vaultId);
    }

    function testCannotCreateProposalWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vm.stopPrank();

        vm.prank(pauser);
        vault.pause();

        vm.prank(signer);
        vm.expectRevert("Pausable: paused");
        vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");
    }

    function testCannotApproveProposalWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vm.stopPrank();

        vm.prank(signer);
        uint256 proposalId = vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");

        vm.prank(pauser);
        vault.pause();

        vm.prank(signer);
        vm.expectRevert("Pausable: paused");
        vault.approveProposal(proposalId);
    }

    function testCannotExecuteProposalWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vm.stopPrank();

        vm.prank(signer);
        uint256 proposalId = vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");

        vm.prank(signer);
        vault.approveProposal(proposalId);

        vm.prank(pauser);
        vault.pause();

        vm.prank(signer);
        vm.expectRevert("Pausable: paused");
        vault.executeProposal(proposalId);
    }

    function testCannotCancelProposalWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vm.stopPrank();

        vm.prank(signer);
        uint256 proposalId = vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");

        vm.prank(pauser);
        vault.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        vault.cancelProposal(proposalId);
    }

    // ============================================
    // Test: View Functions Work When Paused
    // ============================================

    function testViewFunctionsWorkWhenPaused() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vm.stopPrank();

        vm.prank(pauser);
        vault.pause();

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.id, vaultId);

        uint256 count = vault.getVaultCount();
        assertEq(count, 1);

        IMultiVault.Signer memory signerInfo = vault.getSignerInfo(vaultId, signer);
        assertEq(signerInfo.weight, 100);
    }

    // ============================================
    // Test: Resume After Unpause
    // ============================================

    function testResumeOperationsAfterUnpause() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(pauser);
        vault.pause();

        vm.prank(pauser);
        vault.unpause();

        vm.prank(admin);
        vault.addSigner(vaultId, makeAddr("signer1"), 100);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.signerCount, 1);
    }

    // ============================================
    // Test: PayoutExecutor Pause
    // ============================================

    function testCannotCreatePayoutWhenExecutorPaused() public {
        vm.prank(pauser);
        executor.pause();

        vm.prank(address(vault));
        vm.expectRevert("Pausable: paused");
        executor.createOneTimePayout(makeAddr("recipient"), address(0), 100);
    }

    function testCannotClaimPayoutWhenExecutorPaused() public {
        address recipient = makeAddr("recipient");
        vm.deal(address(executor), 1 ether);

        vm.prank(address(vault));
        uint256 payoutId = executor.createOneTimePayout(recipient, address(0), 0.1 ether);

        vm.prank(pauser);
        executor.pause();

        vm.prank(recipient);
        vm.expectRevert("Pausable: paused");
        executor.claim(payoutId);
    }

    function testExecutorCanResumeAfterUnpause() public {
        vm.prank(pauser);
        executor.pause();

        vm.prank(pauser);
        executor.unpause();

        address recipient = makeAddr("recipient");
        vm.prank(address(vault));
        uint256 payoutId = executor.createOneTimePayout(recipient, address(0), 0.1 ether);

        assertTrue(payoutId >= 0);
    }
}

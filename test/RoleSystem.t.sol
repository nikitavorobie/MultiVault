// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RoleSystemTest is Test {
    MultiVault public vault;
    PayoutExecutor public executor;

    address public admin;
    address public vaultAdmin1;
    address public vaultAdmin2;
    address public operator;
    address public pauser;
    address public unauthorized;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        vaultAdmin1 = makeAddr("vaultAdmin1");
        vaultAdmin2 = makeAddr("vaultAdmin2");
        operator = makeAddr("operator");
        pauser = makeAddr("pauser");
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
    }

    // ============================================
    // Test: Role Assignment and Verification
    // ============================================

    function testDefaultAdminRoleGrantedToDeployer() public view {
        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(executor.hasRole(executor.DEFAULT_ADMIN_ROLE(), admin));
    }

    function testOperatorRoleAssignment() public {
        vm.prank(admin);
        vault.grantRole(vault.OPERATOR_ROLE(), operator);

        assertTrue(vault.hasRole(vault.OPERATOR_ROLE(), operator));
    }

    function testPauserRoleAssignment() public {
        vm.prank(admin);
        vault.grantRole(vault.PAUSER_ROLE(), pauser);

        assertTrue(vault.hasRole(vault.PAUSER_ROLE(), pauser));
    }

    function testVaultAdminRoleGrantedOnVaultCreation() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        bytes32 vaultAdminRole = vault.getVaultAdminRole(vaultId);
        assertTrue(vault.hasRole(vaultAdminRole, admin));
    }

    function testVaultAdminRoleCanBeGrantedToOtherAddresses() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        bytes32 vaultAdminRole = vault.getVaultAdminRole(vaultId);

        vm.prank(admin);
        vault.grantRole(vaultAdminRole, vaultAdmin1);

        assertTrue(vault.hasRole(vaultAdminRole, vaultAdmin1));
    }

    function testRoleRevocation() public {
        vm.startPrank(admin);
        vault.grantRole(vault.OPERATOR_ROLE(), operator);
        assertTrue(vault.hasRole(vault.OPERATOR_ROLE(), operator));

        vault.revokeRole(vault.OPERATOR_ROLE(), operator);
        assertFalse(vault.hasRole(vault.OPERATOR_ROLE(), operator));
        vm.stopPrank();
    }

    // ============================================
    // Test: Privilege Escalation Protection
    // ============================================

    function testOperatorCannotGrantRoles() public {
        vault.grantRole(OPERATOR_ROLE, operator);

        vm.prank(operator);
        vm.expectRevert(
            "AccessControl: account 0xbc32b0fcdb9b55f5ece07ba7f8059ba42d331f4c is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        vault.grantRole(OPERATOR_ROLE, unauthorized);
    }

    function testVaultAdminCannotGrantGlobalAdmin() public {
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        bytes32 vaultAdminRole = vault.getVaultAdminRole(vaultId);
        vault.grantRole(vaultAdminRole, vaultAdmin1);

        vm.prank(vaultAdmin1);
        vm.expectRevert(
            "AccessControl: account 0x1bb3cc8eb6e7e6693491585d870614c8218d9319 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        vault.grantRole(DEFAULT_ADMIN_ROLE, unauthorized);
    }

    function testVaultAdminCannotGrantOperatorRole() public {
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        bytes32 vaultAdminRole = vault.getVaultAdminRole(vaultId);
        vault.grantRole(vaultAdminRole, vaultAdmin1);

        vm.prank(vaultAdmin1);
        vm.expectRevert(
            "AccessControl: account 0x1bb3cc8eb6e7e6693491585d870614c8218d9319 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        vault.grantRole(OPERATOR_ROLE, unauthorized);
    }

    function testUnauthorizedCannotCreateVault() public {
        vm.prank(unauthorized);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.createVault("Unauthorized Vault", "ipfs://test");
    }

    function testUnauthorizedCannotArchiveVault() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(unauthorized);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.archiveVault(vaultId);
    }

    function testUnauthorizedCannotAddSigner() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(unauthorized);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.addSigner(vaultId, makeAddr("signer1"), 100);
    }

    // ============================================
    // Test: Cross-Vault Isolation
    // ============================================

    function testVaultAdminCannotModifyOtherVault() public {
        vm.startPrank(admin);
        uint256 vault1 = vault.createVault("Vault 1", "ipfs://1");
        uint256 vault2 = vault.createVault("Vault 2", "ipfs://2");

        vault.grantRole(vault.getVaultAdminRole(vault1), vaultAdmin1);
        vault.grantRole(vault.getVaultAdminRole(vault2), vaultAdmin2);
        vm.stopPrank();

        vm.prank(vaultAdmin1);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.addSigner(vault2, makeAddr("signer"), 100);
    }

    function testVaultAdminCanModifyOwnVault() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        vault.grantRole(vault.getVaultAdminRole(vaultId), vaultAdmin1);
        vm.stopPrank();

        vm.prank(vaultAdmin1);
        vault.addSigner(vaultId, makeAddr("signer1"), 100);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.signerCount, 1);
    }

    function testVaultAdminCanSetThresholdOnOwnVault() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        vault.grantRole(vault.getVaultAdminRole(vaultId), vaultAdmin1);
        vm.stopPrank();

        vm.prank(vaultAdmin1);
        vault.addSigner(vaultId, makeAddr("signer1"), 100);

        vm.prank(vaultAdmin1);
        vault.setThreshold(vaultId, 50);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.threshold, 50);
    }

    function testVaultAdminCanRemoveSignerFromOwnVault() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        vault.grantRole(vault.getVaultAdminRole(vaultId), vaultAdmin1);
        vm.stopPrank();

        address signer1 = makeAddr("signer1");
        address signer2 = makeAddr("signer2");

        vm.startPrank(vaultAdmin1);
        vault.addSigner(vaultId, signer1, 100);
        vault.addSigner(vaultId, signer2, 100);
        vault.removeSigner(vaultId, signer1);
        vm.stopPrank();

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertEq(info.signerCount, 1);
    }

    function testVaultAdminCanUpdateSignerWeightOnOwnVault() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        vault.grantRole(vault.getVaultAdminRole(vaultId), vaultAdmin1);
        vm.stopPrank();

        address signer1 = makeAddr("signer1");

        vm.startPrank(vaultAdmin1);
        vault.addSigner(vaultId, signer1, 100);
        vault.updateSignerWeight(vaultId, signer1, 200);
        vm.stopPrank();

        IMultiVault.Signer memory signerInfo = vault.getSignerInfo(vaultId, signer1);
        assertEq(signerInfo.weight, 200);
    }

    // ============================================
    // Test: GlobalAdmin Powers
    // ============================================

    function testGlobalAdminCanModifyAnyVault() public {
        vm.prank(admin);
        uint256 vault1 = vault.createVault("Vault 1", "ipfs://1");

        vm.prank(admin);
        vault.addSigner(vault1, makeAddr("signer1"), 100);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vault1);
        assertEq(info.signerCount, 1);
    }

    function testGlobalAdminCanArchiveVaults() public {
        vm.prank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");

        vm.prank(admin);
        vault.archiveVault(vaultId);

        IMultiVault.VaultInfo memory info = vault.getVaultInfo(vaultId);
        assertFalse(info.active);
    }

    function testGlobalAdminCanCancelProposals() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vm.stopPrank();

        vm.prank(signer);
        uint256 proposalId = vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");

        vm.prank(admin);
        vault.cancelProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertTrue(proposal.cancelled);
    }

    function testOnlyGlobalAdminCanCancelProposals() public {
        vm.startPrank(admin);
        uint256 vaultId = vault.createVault("Test Vault", "ipfs://test");
        address signer = makeAddr("signer1");
        vault.addSigner(vaultId, signer, 100);
        vault.setThreshold(vaultId, 50);
        vault.grantRole(vault.getVaultAdminRole(vaultId), vaultAdmin1);
        vm.stopPrank();

        vm.prank(signer);
        uint256 proposalId = vault.createProposal(vaultId, makeAddr("recipient"), 100, address(0), "");

        vm.prank(vaultAdmin1);
        vm.expectRevert(MultiVault.Unauthorized.selector);
        vault.cancelProposal(proposalId);
    }
}

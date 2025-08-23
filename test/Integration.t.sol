// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MultiVault.sol";
import "../src/PayoutExecutor.sol";
import "../src/BasePayIntegration.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1000000 * 10**6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract IntegrationTest is Test {
    MultiVault public vault;
    PayoutExecutor public payoutExecutor;
    BasePayIntegration public basePay;
    MockUSDC public usdc;

    address public owner = address(1);
    address public signer1 = address(2);
    address public signer2 = address(3);
    address public recipient = address(4);

    function setUp() public {
        vm.startPrank(owner);

        usdc = new MockUSDC();

        MultiVault vaultImpl = new MultiVault();
        address[] memory signers = new address[](2);
        signers[0] = signer1;
        signers[1] = signer2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 100;
        weights[1] = 100;

        bytes memory vaultInitData = abi.encodeWithSelector(
            MultiVault.initialize.selector,
            signers,
            weights,
            150
        );

        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = MultiVault(payable(address(vaultProxy)));

        PayoutExecutor payoutImpl = new PayoutExecutor();
        bytes memory payoutInitData = abi.encodeWithSelector(
            PayoutExecutor.initialize.selector,
            address(vault)
        );

        ERC1967Proxy payoutProxy = new ERC1967Proxy(address(payoutImpl), payoutInitData);
        payoutExecutor = PayoutExecutor(payable(address(payoutProxy)));

        BasePayIntegration basePayImpl = new BasePayIntegration();
        bytes memory basePayInitData = abi.encodeWithSelector(
            BasePayIntegration.initialize.selector,
            address(vault),
            address(0)
        );

        ERC1967Proxy basePayProxy = new ERC1967Proxy(address(basePayImpl), basePayInitData);
        basePay = BasePayIntegration(payable(address(basePayProxy)));

        vm.deal(address(vault), 100 ether);
        usdc.transfer(address(vault), 10000 * 10**6);

        vm.stopPrank();
    }

    function testFullProposalLifecycle() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        uint256 balanceBefore = recipient.balance;

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        assertEq(recipient.balance, balanceBefore + 1 ether);
    }

    function testERC20ProposalWithPayoutExecutor() public {
        usdc.transfer(address(payoutExecutor), 5000 * 10**6);

        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(
            address(payoutExecutor),
            0,
            address(0),
            abi.encodeWithSelector(
                PayoutExecutor.createVestingPayout.selector,
                recipient,
                address(usdc),
                1000 * 10**6,
                block.timestamp,
                100 days,
                0
            )
        );

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        vm.prank(signer1);
        vault.executeProposal(proposalId);

        vm.warp(block.timestamp + 50 days);

        vm.prank(recipient);
        payoutExecutor.claim(0);

        assertGt(usdc.balanceOf(recipient), 0);
    }

    function testProposalExpiration() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, address(0), "");

        vm.warp(block.timestamp + 31 days);

        vm.prank(signer1);
        vm.expectRevert(MultiVault.ProposalExpired.selector);
        vault.approveProposal(proposalId);
    }

    function testMultiSigWeightThreshold() public {
        vm.prank(signer1);
        uint256 proposalId = vault.createProposal(recipient, 1 ether, address(0), "");

        vm.prank(signer1);
        vault.approveProposal(proposalId);

        IMultiVault.Proposal memory proposal = vault.getProposal(proposalId);
        assertEq(proposal.approvalWeight, 100);
        assertLt(proposal.approvalWeight, vault.getThreshold());

        vm.prank(signer2);
        vault.approveProposal(proposalId);

        proposal = vault.getProposal(proposalId);
        assertGe(proposal.approvalWeight, vault.getThreshold());
    }
}

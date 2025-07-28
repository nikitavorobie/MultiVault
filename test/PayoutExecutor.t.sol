// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/PayoutExecutor.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract PayoutExecutorTest is Test {
    PayoutExecutor public executor;
    PayoutExecutor public implementation;
    MockERC20 public token;

    address public multiVault = address(1);
    address public recipient = address(2);

    function setUp() public {
        vm.startPrank(multiVault);

        implementation = new PayoutExecutor();

        bytes memory initData = abi.encodeWithSelector(
            PayoutExecutor.initialize.selector,
            multiVault
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        executor = PayoutExecutor(payable(address(proxy)));

        token = new MockERC20();
        token.transfer(address(executor), 100000 * 10**18);

        vm.deal(address(executor), 100 ether);
        vm.stopPrank();
    }

    function testCreateOneTimePayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createOneTimePayout(recipient, address(token), 1000 * 10**18);

        PayoutExecutor.Payout memory payout = executor.getPayout(payoutId);
        assertEq(payout.recipient, recipient);
        assertEq(payout.totalAmount, 1000 * 10**18);
        assertEq(payout.payoutType, PayoutExecutor.PayoutType.OneTime);
    }

    function testClaimOneTimePayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createOneTimePayout(recipient, address(token), 1000 * 10**18);

        uint256 balanceBefore = token.balanceOf(recipient);

        vm.prank(recipient);
        executor.claim(payoutId);

        assertEq(token.balanceOf(recipient), balanceBefore + 1000 * 10**18);
    }

    function testCreateVestingPayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createVestingPayout(
            recipient,
            address(token),
            10000 * 10**18,
            block.timestamp,
            365 days,
            30 days
        );

        PayoutExecutor.Payout memory payout = executor.getPayout(payoutId);
        assertEq(payout.payoutType, PayoutExecutor.PayoutType.Vesting);
        assertEq(payout.cliffTime, block.timestamp + 30 days);
    }

    function testVestingClaimBeforeCliff() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createVestingPayout(
            recipient,
            address(token),
            10000 * 10**18,
            block.timestamp,
            365 days,
            30 days
        );

        vm.warp(block.timestamp + 15 days);

        uint256 claimable = executor.getClaimableAmount(payoutId);
        assertEq(claimable, 0);
    }

    function testVestingClaimAfterCliff() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createVestingPayout(
            recipient,
            address(token),
            36500 * 10**18,
            block.timestamp,
            365 days,
            30 days
        );

        vm.warp(block.timestamp + 31 days);

        uint256 claimable = executor.getClaimableAmount(payoutId);
        assertGt(claimable, 0);

        vm.prank(recipient);
        executor.claim(payoutId);

        PayoutExecutor.Payout memory payout = executor.getPayout(payoutId);
        assertGt(payout.claimedAmount, 0);
    }

    function testStreamingPayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createStreamingPayout(
            recipient,
            address(token),
            10000 * 10**18,
            block.timestamp,
            100 days
        );

        vm.warp(block.timestamp + 50 days);

        uint256 claimable = executor.getClaimableAmount(payoutId);
        assertApproxEqAbs(claimable, 5000 * 10**18, 10**18);
    }

    function testCancelPayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createVestingPayout(
            recipient,
            address(token),
            10000 * 10**18,
            block.timestamp,
            365 days,
            0
        );

        vm.prank(multiVault);
        executor.cancelPayout(payoutId);

        PayoutExecutor.Payout memory payout = executor.getPayout(payoutId);
        assertTrue(payout.cancelled);

        uint256 claimable = executor.getClaimableAmount(payoutId);
        assertEq(claimable, 0);
    }

    function testNativeETHPayout() public {
        vm.prank(multiVault);
        uint256 payoutId = executor.createOneTimePayout(recipient, address(0), 1 ether);

        uint256 balanceBefore = recipient.balance;

        vm.prank(recipient);
        executor.claim(payoutId);

        assertEq(recipient.balance, balanceBefore + 1 ether);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PayoutExecutor is UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum PayoutType {
        OneTime,
        Vesting,
        Streaming
    }

    struct Payout {
        uint256 id;
        address recipient;
        address token;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 cliffTime;
        PayoutType payoutType;
        bool cancelled;
    }

    mapping(uint256 => Payout) public payouts;
    uint256 public payoutCount;

    address public multiVault;

    event PayoutCreated(
        uint256 indexed payoutId,
        address indexed recipient,
        address token,
        uint256 amount,
        PayoutType payoutType
    );
    event PayoutClaimed(uint256 indexed payoutId, uint256 amount);
    event PayoutCancelled(uint256 indexed payoutId);

    error Unauthorized();
    error InvalidAmount();
    error InvalidTimeRange();
    error PayoutNotFound();
    error PayoutAlreadyCancelled();
    error NothingToClaim();
    error CliffNotReached();

    modifier onlyMultiVault() {
        if (msg.sender != multiVault) revert Unauthorized();
        _;
    }

    function initialize(address _multiVault) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        multiVault = _multiVault;
    }

    /// @notice Reinitializer for migrating from Ownable to AccessControl
    /// @dev Call this during upgrade from v1 to v2 to grant admin role to deployer
    function initializeV2() public reinitializer(2) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function createOneTimePayout(
        address recipient,
        address token,
        uint256 amount
    ) external onlyMultiVault whenNotPaused returns (uint256) {
        if (amount == 0) revert InvalidAmount();

        uint256 payoutId = payoutCount++;

        payouts[payoutId] = Payout({
            id: payoutId,
            recipient: recipient,
            token: token,
            totalAmount: amount,
            claimedAmount: 0,
            startTime: block.timestamp,
            endTime: block.timestamp,
            cliffTime: 0,
            payoutType: PayoutType.OneTime,
            cancelled: false
        });

        emit PayoutCreated(payoutId, recipient, token, amount, PayoutType.OneTime);
        return payoutId;
    }

    function createVestingPayout(
        address recipient,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration
    ) external onlyMultiVault whenNotPaused returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        if (duration == 0) revert InvalidTimeRange();
        if (startTime < block.timestamp) startTime = block.timestamp;

        uint256 payoutId = payoutCount++;
        uint256 endTime = startTime + duration;
        uint256 cliffTime = cliffDuration > 0 ? startTime + cliffDuration : 0;

        payouts[payoutId] = Payout({
            id: payoutId,
            recipient: recipient,
            token: token,
            totalAmount: amount,
            claimedAmount: 0,
            startTime: startTime,
            endTime: endTime,
            cliffTime: cliffTime,
            payoutType: PayoutType.Vesting,
            cancelled: false
        });

        emit PayoutCreated(payoutId, recipient, token, amount, PayoutType.Vesting);
        return payoutId;
    }

    function createStreamingPayout(
        address recipient,
        address token,
        uint256 amount,
        uint256 startTime,
        uint256 duration
    ) external onlyMultiVault whenNotPaused returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        if (duration == 0) revert InvalidTimeRange();
        if (startTime < block.timestamp) startTime = block.timestamp;

        uint256 payoutId = payoutCount++;
        uint256 endTime = startTime + duration;

        payouts[payoutId] = Payout({
            id: payoutId,
            recipient: recipient,
            token: token,
            totalAmount: amount,
            claimedAmount: 0,
            startTime: startTime,
            endTime: endTime,
            cliffTime: 0,
            payoutType: PayoutType.Streaming,
            cancelled: false
        });

        emit PayoutCreated(payoutId, recipient, token, amount, PayoutType.Streaming);
        return payoutId;
    }

    function claim(uint256 payoutId) external whenNotPaused {
        Payout storage payout = payouts[payoutId];
        if (payout.startTime == 0) revert PayoutNotFound();
        if (payout.cancelled) revert PayoutAlreadyCancelled();
        if (msg.sender != payout.recipient) revert Unauthorized();

        uint256 claimable = getClaimableAmount(payoutId);
        if (claimable == 0) revert NothingToClaim();

        payout.claimedAmount += claimable;

        if (payout.token == address(0)) {
            (bool success, ) = payout.recipient.call{value: claimable}("");
            require(success, "Transfer failed");
        } else {
            IERC20(payout.token).safeTransfer(payout.recipient, claimable);
        }

        emit PayoutClaimed(payoutId, claimable);
    }

    function cancelPayout(uint256 payoutId) external onlyMultiVault whenNotPaused {
        Payout storage payout = payouts[payoutId];
        if (payout.startTime == 0) revert PayoutNotFound();
        if (payout.cancelled) revert PayoutAlreadyCancelled();

        payout.cancelled = true;
        emit PayoutCancelled(payoutId);
    }

    function getClaimableAmount(uint256 payoutId) public view returns (uint256) {
        Payout storage payout = payouts[payoutId];
        if (payout.startTime == 0) revert PayoutNotFound();
        if (payout.cancelled) return 0;

        if (payout.payoutType == PayoutType.OneTime) {
            return payout.totalAmount - payout.claimedAmount;
        }

        if (payout.cliffTime > 0 && block.timestamp < payout.cliffTime) {
            return 0;
        }

        if (block.timestamp >= payout.endTime) {
            return payout.totalAmount - payout.claimedAmount;
        }

        uint256 elapsed = block.timestamp - payout.startTime;
        uint256 duration = payout.endTime - payout.startTime;
        uint256 vested = (payout.totalAmount * elapsed) / duration;

        return vested > payout.claimedAmount ? vested - payout.claimedAmount : 0;
    }

    function getPayout(uint256 payoutId) external view returns (Payout memory) {
        return payouts[payoutId];
    }

    function pause() external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(PAUSER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _pause();
    }

    function unpause() external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(PAUSER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
    }

    receive() external payable {}
}

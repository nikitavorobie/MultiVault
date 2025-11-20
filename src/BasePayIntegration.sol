// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBasePay.sol";

contract BasePayIntegration is UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    address public constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public basePay;
    address public multiVault;

    event USDCTransferExecuted(address indexed recipient, uint256 amount);
    event BatchTransferExecuted(uint256 recipientCount, uint256 totalAmount);
    event BasePayUpdated(address indexed newBasePay);

    error Unauthorized();
    error InvalidRecipient();
    error InvalidAmount();
    error TransferFailed();
    error ArrayLengthMismatch();

    modifier onlyMultiVault() {
        if (msg.sender != multiVault) revert Unauthorized();
        _;
    }

    function initialize(address _multiVault, address _basePay) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        multiVault = _multiVault;
        basePay = _basePay;
    }

    function transferUSDC(address recipient, uint256 amount) external onlyMultiVault returns (bool) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        if (basePay != address(0)) {
            IERC20(USDC_BASE).approve(basePay, amount);
            bool success = IBasePay(basePay).transfer(USDC_BASE, recipient, amount);
            if (!success) revert TransferFailed();
        } else {
            IERC20(USDC_BASE).safeTransfer(recipient, amount);
        }

        emit USDCTransferExecuted(recipient, amount);
        return true;
    }

    function batchTransferUSDC(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyMultiVault returns (bool) {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        if (recipients.length == 0) revert InvalidRecipient();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (recipients[i] == address(0)) revert InvalidRecipient();
            if (amounts[i] == 0) revert InvalidAmount();
            totalAmount += amounts[i];
        }

        if (basePay != address(0)) {
            IERC20(USDC_BASE).approve(basePay, totalAmount);
            bool success = IBasePay(basePay).batchTransfer(USDC_BASE, recipients, amounts);
            if (!success) revert TransferFailed();
        } else {
            for (uint256 i = 0; i < recipients.length; i++) {
                IERC20(USDC_BASE).safeTransfer(recipients[i], amounts[i]);
            }
        }

        emit BatchTransferExecuted(recipients.length, totalAmount);
        return true;
    }

    function updateBasePay(address newBasePay) external onlyOwner {
        basePay = newBasePay;
        emit BasePayUpdated(newBasePay);
    }

    function withdrawUSDC(address recipient, uint256 amount) external onlyOwner {
        IERC20(USDC_BASE).safeTransfer(recipient, amount);
    }

    function getUSDCBalance() external view returns (uint256) {
        return IERC20(USDC_BASE).balanceOf(address(this));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPrizeVaultListener {
    function beforeClaimPrize(address user, uint8 tier, address prizeRecipient) external;
    function beforeTokenTransfer(address from, address to, uint256 amount) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

struct VaultHooks {
  /// @notice If true, the vault will call the beforeClaimPrize hook on the implementation
  bool useBeforeClaimPrize;
  /// @notice The address of the smart contract implementing the hooks
  IVaultHooks implementation;
}

/// @title  PoolTogether V5 Vault Hooks Interface
/// @author PoolTogether Inc Team, Generation Software Team
/// @notice Allows winners to attach smart contract hooks to their prize winnings
interface IVaultHooks {
  /// @notice Triggered before the prize pool claim prize function is called.
  /// @param winner The user who won the prize and for whom this hook is attached
  /// @param tier The tier of the prize
  /// @param prizeIndex The index of the prize in the tier
  /// @return address The address of the recipient of the prize
  function beforeClaimPrize(
    address winner,
    uint8 tier,
    uint32 prizeIndex,
    uint256 fee,
    address feeRecipient
  ) external returns (address);
}
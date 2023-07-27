// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct VaultHooks {
  /// @notice If true, the vault will call the beforeClaimPrize hook on the implementation
  bool useBeforeClaimPrize;
  /// @notice If true, the vault will call the afterClaimPrize hook on the implementation
  bool useAfterClaimPrize;
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
    uint32 prizeIndex
  ) external returns (address);

  /// @notice Triggered after the prize pool claim prize function is called.
  /// @param winner The user who won the prize and for whom this hook is attached
  /// @param tier The tier of the prize
  /// @param prizeIndex The index of the prize
  /// @param payout The amount of tokens paid out to the recipient
  /// @param recipient The recipient of the prize
  function afterClaimPrize(
    address winner,
    uint8 tier,
    uint32 prizeIndex,
    uint256 payout,
    address recipient
  ) external;
}

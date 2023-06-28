// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

struct Hook {
    /// @notice If true, the vault will call the beforeClaimPrize fxn on the hook.
    bool useBeforeClaimHook;
    /// @notice If true, the vault will call the afterClaimPrize on the hook
    bool useAfterClaimHook;
    /// @notice The address of the smart contarct implementing the hooks
    IVaultHooks hooks;
}

/// @notice Allows winners to attach smart contract hooks to their prize winnings
interface IVaultHooks {
    
    /// @notice Triggered before the prize pool claim prize function is called.
    /// @param winner The user who won the prize and for whom this hook is attached
    /// @param tier The tier of the prize
    /// @param prizeIndex The index of the prize in the tier
    /// @return The address of the recipient of the prize
    function beforeClaimPrize(address winner, uint8 tier, uint32 prizeIndex) external returns (address);

    /// @notice Triggered after the prize pool claim prize function is called.
    /// @param winner The user who won the prize and for whom this hook is attached
    /// @param tier The tier of the prize
    /// @param prizeIndex The index of the prize
    /// @param payout The amount of tokens paid out to the recipient
    /// @param recipient The recipient of the prize
    function afterClaimPrize(address winner, uint8 tier, uint32 prizeIndex, uint256 payout, address recipient) external;
}
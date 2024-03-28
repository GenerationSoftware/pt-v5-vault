// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Defines a hook implementation and instructions on which hooks to call.
/// @param useBeforeClaimPrize If true, the vault will call the beforeClaimPrize hook on the implementation
/// @param useAfterClaimPrize If true, the vault will call the afterClaimPrize hook on the implementation
/// @param implementation The address of the smart contract implementing the hooks
struct PrizeHooks {
    bool useBeforeClaimPrize;
    bool useAfterClaimPrize;
    IPrizeHooks implementation;
}

/// @title  PoolTogether V5 Prize Hooks Interface
/// @author PoolTogether Inc. & G9 Software Inc.
/// @notice Allows winners to attach smart contract hooks to their prize winnings
interface IPrizeHooks {
    
    /// @notice Triggered before the prize pool claim prize function is called.
    /// @param winner The user who won the prize and for whom this hook is attached
    /// @param tier The tier of the prize
    /// @param prizeIndex The index of the prize in the tier
    /// @param reward The reward portion of the prize that will be allocated to the claimer
    /// @param rewardRecipient The recipient of the claim reward
    /// @return prizeRecipient The address of the recipient of the prize
    /// @return data Arbitrary data that will be passed to the `afterClaimPrize` hook
    function beforeClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint96 reward,
        address rewardRecipient
    ) external returns (address prizeRecipient, bytes memory data);

    /// @notice Triggered after the prize pool claim prize function is called.
    /// @param winner The user who won the prize and for whom this hook is attached
    /// @param tier The tier of the prize
    /// @param prizeIndex The index of the prize
    /// @param prize The total size of the prize (not including the claim reward)
    /// @param prizeRecipient The recipient of the prize
    /// @param data Arbitrary data received from the `beforeClaimPrize` hook
    function afterClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint256 prize,
        address prizeRecipient,
        bytes memory data
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @notice Defines a hook implementation and instructions on which hooks to call.
 * @param useBeforeClaimPrize If true, the vault will call the beforeClaimPrize hook on the implementation
 * @param useAfterClaimPrize If true, the vault will call the afterClaimPrize hook on the implementation
 * @param implementation The address of the smart contract implementing the hooks
 */
struct VaultHooks {
    bool useBeforeClaimPrize;
    bool useAfterClaimPrize;
    IVaultHooks implementation;
}

/**
 * @title  PoolTogether V5 Vault Hooks Interface
 * @author PoolTogether Inc. & G9 Software Inc.
 * @notice Allows winners to attach smart contract hooks to their prize winnings
 */
interface IVaultHooks {
    
    /**
     * @notice Triggered before the prize pool claim prize function is called.
     * @param winner The user who won the prize and for whom this hook is attached
     * @param tier The tier of the prize
     * @param prizeIndex The index of the prize in the tier
     * @param fee The fee portion of the prize that will be allocated to the claimer
     * @param feeRecipient The recipient of the claim fee
     * @return address The address of the recipient of the prize
     */
    function beforeClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint96 fee,
        address feeRecipient
    ) external returns (address);

    /**
     * @notice Triggered after the prize pool claim prize function is called.
     * @param winner The user who won the prize and for whom this hook is attached
     * @param tier The tier of the prize
     * @param prizeIndex The index of the prize
     * @param prize The total size of the prize (payout + fee)
     * @param recipient The recipient of the prize
     */
    function afterClaimPrize(
        address winner,
        uint8 tier,
        uint32 prizeIndex,
        uint256 prize,
        address recipient
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IClaimable } from "pt-v5-claimable-interface/interfaces/IClaimable.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";

import { HookManager } from "./HookManager.sol";

/// @title  PoolTogether V5 Claimable Vault Extension
/// @author G9 Software Inc.
/// @notice Provides an interface for Claimer contracts to interact with a vault in PoolTogether
/// V5 while allowing each account to set and manage prize hooks that are called when they win.
abstract contract Claimable is HookManager, IClaimable {

    ////////////////////////////////////////////////////////////////////////////////
    // Public Constants and Variables
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice The gas to give to each of the before and after prize claim hooks.
    /// @dev This should be enough gas to mint an NFT if needed.
    uint24 public constant HOOK_GAS = 150_000;

    /// @notice Address of the PrizePool that computes prizes.
    PrizePool public immutable prizePool;

    /// @notice Address of the claimer.
    address public claimer;

    ////////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the Prize Pool is set to the zero address.
    error PrizePoolZeroAddress();

    /// @notice Thrown when the Claimer is set to the zero address.
    error ClaimerZeroAddress();

    /// @notice Thrown when a prize is claimed for the zero address.
    error ClaimRecipientZeroAddress();

    /// @notice Thrown when the caller is not the prize claimer.
    /// @param caller The caller address
    /// @param claimer The claimer address
    error CallerNotClaimer(address caller, address claimer);

    ////////////////////////////////////////////////////////////////////////////////
    // Modifiers
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Requires the caller to be the claimer.
    modifier onlyClaimer() {
        if (msg.sender != claimer) revert CallerNotClaimer(msg.sender, claimer);
        _;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Claimable constructor
    /// @param prizePool_ The prize pool to claim prizes from
    /// @param claimer_ The address allowed to claim prizes on behalf of winners
    constructor(PrizePool prizePool_, address claimer_) {
        if (address(prizePool_) == address(0)) revert PrizePoolZeroAddress();
        prizePool = prizePool_;
        _setClaimer(claimer_);
    }

    ////////////////////////////////////////////////////////////////////////////////
    // IClaimable Implementation
    ////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc IClaimable
    /// @dev Also calls the before and after claim hooks if set by the winner.
    function claimPrize(
        address _winner,
        uint8 _tier,
        uint32 _prizeIndex,
        uint96 _reward,
        address _rewardRecipient
    ) external onlyClaimer returns (uint256) {
        address recipient;

        if (_hooks[_winner].useBeforeClaimPrize) {
            recipient = _hooks[_winner].implementation.beforeClaimPrize{ gas: HOOK_GAS }(
                _winner,
                _tier,
                _prizeIndex,
                _reward,
                _rewardRecipient
            );
        } else {
            recipient = _winner;
        }

        if (recipient == address(0)) revert ClaimRecipientZeroAddress();

        uint256 prizeTotal = prizePool.claimPrize(
            _winner,
            _tier,
            _prizeIndex,
            recipient,
            _reward,
            _rewardRecipient
        );

        if (_hooks[_winner].useAfterClaimPrize) {
            _hooks[_winner].implementation.afterClaimPrize{ gas: HOOK_GAS }(
                _winner,
                _tier,
                _prizeIndex,
                prizeTotal,
                recipient
            );
        }

        return prizeTotal;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internal Helpers
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Set claimer address.
    /// @dev Will revert if `_claimer` is address zero.
    /// @param _claimer Address of the claimer
    function _setClaimer(address _claimer) internal {
        if (_claimer == address(0)) revert ClaimerZeroAddress();
        claimer = _claimer;
        emit ClaimerSet(_claimer);
    }
    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IClaimable } from "pt-v5-claimable-interface/interfaces/IClaimable.sol";
import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { ExcessivelySafeCall  } from "excessively-safe-call/ExcessivelySafeCall.sol";

import { HookManager } from "./HookManager.sol";
import { IPrizeHooks } from "../interfaces/IPrizeHooks.sol";

/// @title  PoolTogether V5 Claimable Vault Extension
/// @author G9 Software Inc.
/// @notice Provides an interface for Claimer contracts to interact with a vault in PoolTogether
/// V5 while allowing each account to set and manage prize hooks that are called when they win.
abstract contract Claimable is HookManager, IClaimable {
    using ExcessivelySafeCall for address;

    ////////////////////////////////////////////////////////////////////////////////
    // Public Constants and Variables
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice The gas to give to each of the before and after prize claim hooks.
    /// @dev This should be enough gas to mint an NFT if needed.
    uint24 public constant HOOK_GAS = 150_000;

    /// @notice The number of bytes to limit hook return / revert data.
    /// @dev If this limit is exceeded for `beforeClaimPrize` return data, the claim will revert.
    /// @dev Revert data for both hooks will also be limited to this size.
    /// @dev 128 bytes is enough for `beforeClaimPrize` to return the `_prizeRecipient` address as well
    /// as 32 bytes of additional `_hookData` byte string data (32 for offset, 32 for length, 32 for data).
    uint16 public constant HOOK_RETURN_DATA_LIMIT = 128;

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

    /// @notice Thrown if relevant hook return data is greater than the `HOOK_RETURN_DATA_LIMIT`.
    /// @param returnDataSize The actual size of the return data
    /// @param hookDataLimit The return data size limit for hooks
    error ReturnDataOverLimit(uint256 returnDataSize, uint256 hookDataLimit);

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
    /// @dev Reverts if the return data size of the `beforeClaimPrize` hook exceeds `HOOK_RETURN_DATA_LIMIT`.
    function claimPrize(
        address _winner,
        uint8 _tier,
        uint32 _prizeIndex,
        uint96 _reward,
        address _rewardRecipient
    ) external onlyClaimer returns (uint256) {
        address _prizeRecipient;
        bytes memory _hookData;

        if (_hooks[_winner].useBeforeClaimPrize) {
            (bytes memory _returnData, uint256 _actualReturnDataSize) = _safeHookCall(
                _hooks[_winner].implementation,
                abi.encodeWithSelector(
                    IPrizeHooks.beforeClaimPrize.selector,
                    _winner,
                    _tier,
                    _prizeIndex,
                    _reward,
                    _rewardRecipient
                )
            );
            // If the actual return data is greater than the `HOOK_RETURN_DATA_LIMIT` then we must revert since the
            // integrity of the data is not guaranteed.
            if (_actualReturnDataSize > HOOK_RETURN_DATA_LIMIT) {
                revert ReturnDataOverLimit(_actualReturnDataSize, HOOK_RETURN_DATA_LIMIT);
            }
            (_prizeRecipient, _hookData) = abi.decode(_returnData, (address, bytes));
        } else {
            _prizeRecipient = _winner;
        }

        if (_prizeRecipient == address(0)) revert ClaimRecipientZeroAddress();

        _beforeClaimPrize(_winner, _tier, _prizeRecipient);
        uint256 _prizeTotal = prizePool.claimPrize(
            _winner,
            _tier,
            _prizeIndex,
            _prizeRecipient,
            _reward,
            _rewardRecipient
        );

        if (_hooks[_winner].useAfterClaimPrize) {
            _safeHookCall(
                _hooks[_winner].implementation,
                abi.encodeWithSelector(
                    IPrizeHooks.afterClaimPrize.selector,
                    _winner,
                    _tier,
                    _prizeIndex,
                    _prizeTotal - _reward,
                    _prizeRecipient,
                    _hookData
                )
            );
        }

        return _prizeTotal;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internal Helpers
    ////////////////////////////////////////////////////////////////////////////////

    function _beforeClaimPrize(address winner, uint8 tier, address prizeRecipient) internal virtual {}

    /// @notice Set claimer address.
    /// @dev Will revert if `_claimer` is address zero.
    /// @param _claimer Address of the claimer
    function _setClaimer(address _claimer) internal {
        if (_claimer == address(0)) revert ClaimerZeroAddress();
        claimer = _claimer;
        emit ClaimerSet(_claimer);
    }

    /// @notice Uses ExcessivelySafeCall to limit the return data size to a safe limit.
    /// @dev This is used for both hook calls to prevent gas bombs that can be triggered using a large
    /// amount of return data or a large revert string.
    /// @dev In the case of an unsuccessful call, the revert reason will be bubbled up if it is within
    /// the safe data limit. Otherwise, a `ReturnDataOverLimit` reason will be thrown.
    /// @return _returnData The safe, size limited return data
    /// @return _actualReturnDataSize The actual return data size of the original result
    function _safeHookCall(IPrizeHooks _implementation, bytes memory _calldata) internal returns (bytes memory _returnData, uint256 _actualReturnDataSize) {
        bool _success;
        (_success, _returnData) = address(_implementation).excessivelySafeCall(
            HOOK_GAS,
            0, // value
            HOOK_RETURN_DATA_LIMIT,
            _calldata
        );
        assembly {
            _actualReturnDataSize := returndatasize()
        }

        if (!_success) {
            // If we can't access the full revert data, we use a generic revert
            if (_actualReturnDataSize > HOOK_RETURN_DATA_LIMIT) {
                revert ReturnDataOverLimit(_actualReturnDataSize, HOOK_RETURN_DATA_LIMIT);
            }
            // Otherwise, we use a low level revert to bubble up the revert reason
            assembly {
                revert(add(32, _returnData), mload(_returnData))
            }
        }
    }
    
}

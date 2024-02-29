// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { VaultHooks } from "../interfaces/IVaultHooks.sol";

/// @title  PoolTogether V5 HookManager
/// @author G9 Software Inc.
/// @notice Allows each account to set and manage prize hooks that can be called when they win.
abstract contract HookManager {

    /// @notice Emitted when an account sets new hooks
    /// @param account The account whose hooks are being configured
    /// @param hooks The hooks being set
    event SetHooks(address indexed account, VaultHooks hooks);

    /// @notice Maps user addresses to hooks that they want to execute when prizes are won.
    mapping(address => VaultHooks) internal _hooks;

    /// @notice Gets the hooks for the given account.
    /// @param account The account to retrieve the hooks for
    /// @return VaultHooks The hooks for the given account
    function getHooks(address account) external view returns (VaultHooks memory) {
        return _hooks[account];
    }

    /// @notice Sets the hooks for a winner.
    /// @dev Emits a `SetHooks` event
    /// @param hooks The hooks to set
    function setHooks(VaultHooks calldata hooks) external {
        _hooks[msg.sender] = hooks;
        emit SetHooks(msg.sender, hooks);
    }
    
}
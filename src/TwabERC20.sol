// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { SafeCast } from "openzeppelin/utils/math/SafeCast.sol";

import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

/// @title  PoolTogether V5 TWAB ERC20 Token
/// @author G9 Software Inc.
/// @notice This contract creates an ERC20 token with balances stored in a TwabController,
///         enabling time-weighted average balances for each depositor and token compatibility
///         with the PoolTogether V5 Prize Pool.
/// @dev    This contract is designed to be used as an accounting layer when building a vault
///         for PoolTogether V5.
/// @dev    The TwabController limits all balances including total token supply to uint96 for
///         gas savings. Any mints that increase a balance past this limit will fail.
contract TwabERC20 is ERC20, ERC20Permit {

    ////////////////////////////////////////////////////////////////////////////////
    // Public Variables
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Address of the TwabController used to keep track of balances.
    TwabController public immutable twabController;

    ////////////////////////////////////////////////////////////////////////////////
    // Errors
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Thrown if the TwabController address is the zero address.
    error TwabControllerZeroAddress();

    ////////////////////////////////////////////////////////////////////////////////
    // Constructor
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice TwabERC20 Constructor
    /// @param name_ The name of the token
    /// @param symbol_ The token symbol
    constructor(
        string memory name_,
        string memory symbol_,
        TwabController twabController_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        if (address(0) == address(twabController_)) revert TwabControllerZeroAddress();
        twabController = twabController_;
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Public ERC20 Overrides
    ////////////////////////////////////////////////////////////////////////////////

    /// @inheritdoc ERC20
    function balanceOf(
        address _account
    ) public view virtual override(ERC20) returns (uint256) {
        return twabController.balanceOf(address(this), _account);
    }

    /// @inheritdoc ERC20
    function totalSupply() public view virtual override(ERC20) returns (uint256) {
        return twabController.totalSupply(address(this));
    }

    ////////////////////////////////////////////////////////////////////////////////
    // Internal ERC20 Overrides
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Mints tokens to `_receiver` and increases the total supply.
    /// @dev Emits a {Transfer} event with `from` set to the zero address.
    /// @dev `_receiver` cannot be the zero address.
    /// @param _receiver Address that will receive the minted tokens
    /// @param _amount Tokens to mint
    function _mint(address _receiver, uint256 _amount) internal virtual override {
        twabController.mint(_receiver, SafeCast.toUint96(_amount));
        emit Transfer(address(0), _receiver, _amount);
    }

    /// @notice Destroys tokens from `_owner` and reduces the total supply.
    /// @dev Emits a {Transfer} event with `to` set to the zero address.
    /// @dev `_owner` cannot be the zero address.
    /// @dev `_owner` must have at least `_amount` tokens.
    /// @param _owner The owner of the tokens
    /// @param _amount The amount of tokens to burn
    function _burn(address _owner, uint256 _amount) internal virtual override {
        twabController.burn(_owner, SafeCast.toUint96(_amount));
        emit Transfer(_owner, address(0), _amount);
    }

    /// @notice Transfers tokens from one account to another.
    /// @dev Emits a {Transfer} event.
    /// @dev `_from` cannot be the zero address.
    /// @dev `_to` cannot be the zero address.
    /// @dev `_from` must have a balance of at least `_amount`.
    /// @param _from Address to transfer from
    /// @param _to Address to transfer to
    /// @param _amount The amount of tokens to transfer
    function _transfer(address _from, address _to, uint256 _amount) internal virtual override {
        twabController.transfer(_from, _to, SafeCast.toUint96(_amount));
        emit Transfer(_from, _to, _amount);
    }

}
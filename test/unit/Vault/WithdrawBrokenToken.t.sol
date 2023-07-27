// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBrokenTokenBaseSetup } from "../../utils/UnitBrokenTokenBaseSetup.t.sol";

contract VaultWithdrawBrokenTokenTest is UnitBrokenTokenBaseSetup {
  /* ============ Events ============ */
  event Withdraw(
    address indexed sender,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  event Transfer(address indexed from, address indexed to, uint256 value);

  function setUp() public pure override {
    return;
  }

  /* ============ BrokenTokens ============ */
  function testWithdrawBrokenToken() public useBrokenToken {
    bytes32 brokenERC20Name = keccak256(bytes(brokenERC20_NAME));

    /**
     * These tokens are not tested for the following reasons:
     * - ReturnsFalseToken and MissingReturnToken revert on approval
     * - TransferFeeToken: we don't support fee on transfer tokens
     * - HighDecimalToken: Token with 50 decimals, reverts on deposit
     */
    if (
      brokenERC20Name == keccak256(bytes("ReturnsFalseToken")) ||
      brokenERC20Name == keccak256(bytes("MissingReturnToken")) ||
      brokenERC20Name == keccak256(bytes("TransferFeeToken")) ||
      brokenERC20Name == keccak256(bytes("HighDecimalToken"))
    ) {
      return;
    }

    super.setUp();

    uint256 _amount = 1000 * 10 ** underlyingAsset.decimals();

    deal(address(brokenERC20), alice, _amount);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _amount, _amount);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(yieldVault.balanceOf(address(vault)), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 0);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }
}

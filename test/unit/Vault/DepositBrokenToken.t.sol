// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBrokenTokenBaseSetup } from "../../utils/UnitBrokenTokenBaseSetup.t.sol";
import "../../../src/Vault.sol";

contract VaultDepositBrokenTokenTest is UnitBrokenTokenBaseSetup {
  /* ============ Events ============ */
  event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  event Transfer(address indexed from, address indexed to, uint256 value);

  function setUp() public pure override {
    return;
  }

  function testDepositBrokenToken() public useBrokenToken {
    bytes32 brokenERC20Name = keccak256(bytes(brokenERC20_NAME));

    /**
     * These tokens are not tested for the following reasons:
     * - ReturnsFalseToken and MissingReturnToken revert on approval
     * - TransferFeeToken: we don't support fee on transfer tokens
     */
    if (
      brokenERC20Name == keccak256(bytes("ReturnsFalseToken")) ||
      brokenERC20Name == keccak256(bytes("MissingReturnToken")) ||
      brokenERC20Name == keccak256(bytes("TransferFeeToken"))
    ) {
      return;
    }

    super.setUp();

    uint256 _amount = 1000 * 10 ** underlyingAsset.decimals();

    deal(address(brokenERC20), alice, _amount);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    vm.startPrank(alice);
    underlyingAsset.approve(address(vault), type(uint256).max);

    // Token with 50 decimals, amount is greater than type(uint96).max
    if (brokenERC20Name == keccak256(bytes("HighDecimalToken"))) {
      vm.expectRevert(
        abi.encodeWithSelector(Vault.DepositMoreThanMax.selector, alice, _amount, type(uint96).max)
      );

      vault.deposit(_amount, alice);

      vm.stopPrank();
      return;
    }

    vm.expectEmit();
    emit Transfer(address(0), alice, _amount);

    vm.expectEmit();
    emit Deposit(alice, alice, _amount, _amount);

    vault.deposit(_amount, alice);

    assertEq(vault.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _amount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }
}

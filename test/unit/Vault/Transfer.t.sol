// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";

contract VaultTransferTest is UnitBaseSetup {
  /* ============ Events ============ */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /* ============ Tests ============ */

  /* ============ Deposit ============ */
  function testTransfer() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, bob, _amount);

    vault.transfer(bob, _amount);

    assertEq(vault.balanceOf(bob), _amount);
    assertEq(vault.balanceOf(alice), 0);

    assertEq(twabController.balanceOf(address(vault), bob), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }

  function testTransferHalfAmount() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    uint256 _halfAmount = _amount / 2;

    underlyingAsset.mint(alice, _amount);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, bob, _halfAmount);

    vault.transfer(bob, _halfAmount);

    assertEq(vault.balanceOf(bob), _halfAmount);
    assertEq(vault.balanceOf(alice), _halfAmount);

    assertEq(twabController.balanceOf(address(vault), bob), _halfAmount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _halfAmount);

    assertEq(twabController.balanceOf(address(vault), alice), _halfAmount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _halfAmount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);
    assertEq(yieldVault.totalSupply(), _amount);

    vm.stopPrank();
  }
}

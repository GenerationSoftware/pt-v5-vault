// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup, IERC20 } from "../../utils/UnitBaseSetup.t.sol";
import { WithdrawMoreThanMax, RedeemMoreThanMax } from "../../../src/Vault.sol";

contract VaultWithdrawTest is UnitBaseSetup {
  /* ============ Events ============ */
  event Withdraw(
    address indexed sender,
    address indexed receiver,
    address indexed owner,
    uint256 assets,
    uint256 shares
  );

  event Transfer(address indexed from, address indexed to, uint256 value);

  /* ============ Tests ============ */

  /* ============ Withdraw ============ */
  function testWithdraw() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
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

  function testWithdrawMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectRevert(abi.encodeWithSelector(WithdrawMoreThanMax.selector, alice, _amount + 1, _amount));
    vault.withdraw(_amount + 1, alice, alice);

    vm.stopPrank();
  }

  function testWithdrawHalfAmount() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    uint256 _halfAmount = _amount / 2;
    underlyingAsset.mint(alice, _amount);
    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _halfAmount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _halfAmount, _halfAmount);

    vault.withdraw(_halfAmount, alice, alice);

    assertEq(vault.balanceOf(alice), _halfAmount);
    assertEq(underlyingAsset.balanceOf(alice), _halfAmount);

    assertEq(twabController.balanceOf(address(vault), alice), _halfAmount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _halfAmount);

    assertEq(yieldVault.maxWithdraw(address(vault)), _halfAmount);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _halfAmount);
    assertEq(vault.totalSupply(), _halfAmount);

    vm.stopPrank();
  }

  function testWithdrawFullAmountYieldAccrued() external {
    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.stopPrank();

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _amount, _amount);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(yieldVault.maxWithdraw(address(vault)), _yield);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _yield);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }

  function testWithdrawOnBehalf() external {
    uint256 _amount = 1000e18;
    underlyingAsset.mint(bob, _amount);

    vm.startPrank(bob);

    _deposit(underlyingAsset, vault, _amount, bob);
    IERC20(vault).approve(alice, _amount);

    vm.stopPrank();

    vm.startPrank(alice);

    vm.expectEmit();
    emit Transfer(bob, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, bob, bob, _amount, _amount);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);

    assertEq(vault.balanceOf(bob), 0);
    assertEq(underlyingAsset.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), 0);

    assertEq(yieldVault.balanceOf(address(vault)), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 0);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }

  /* ============ Withdraw - Attacks ============ */
  function testWithdrawOverflow() external {
    uint256 _amount = type(uint96).max;
    uint256 _doubleAmount = _amount * 2;

    vm.startPrank(bob);

    underlyingAsset.mint(bob, _doubleAmount);
    underlyingAsset.approve(address(vault), _doubleAmount);

    // Need to deposit in two steps cause it would overflow over the maxDeposit limit of uint96 otherwise
    // NOTE: this is only possible cause balances are stored in uint112 in the TwabController, it would revert if it was uint96
    vault.deposit(_amount, bob);
    vault.deposit(_amount, bob);

    assertEq(vault.balanceOf(bob), _doubleAmount);

    assertEq(twabController.balanceOf(address(vault), bob), _doubleAmount);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), _doubleAmount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _doubleAmount);
    assertEq(yieldVault.balanceOf(address(vault)), _doubleAmount);
    assertEq(yieldVault.totalSupply(), _doubleAmount);

    uint256 _bobMaxWithdraw = vault.maxWithdraw(bob);
    assertEq(_bobMaxWithdraw, _doubleAmount);

    vm.expectRevert(bytes("SafeCast: value doesn't fit in 96 bits"));
    vault.withdraw(_bobMaxWithdraw, bob, bob);
  }

  /* ============ Redeem ============ */
  function testRedeemFullAmount() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _amount, _amount);

    vault.redeem(vault.maxRedeem(alice), alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 0);
    assertEq(yieldVault.balanceOf(address(vault)), 0);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }

  function testRedeemMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    uint256 _shares = _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectRevert(abi.encodeWithSelector(RedeemMoreThanMax.selector, alice, _shares + 1, _shares));
    vault.redeem(_shares + 1, alice, alice);

    vm.stopPrank();
  }

  function testRedeemHalfAmount() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    uint256 _halfAmount = _amount / 2;
    underlyingAsset.mint(alice, _amount);

    uint256 _shares = _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _halfAmount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _halfAmount, _halfAmount);

    vault.redeem(_shares / 2, alice, alice);

    assertEq(vault.balanceOf(alice), _halfAmount);
    assertEq(underlyingAsset.balanceOf(alice), _halfAmount);

    assertEq(twabController.balanceOf(address(vault), alice), _halfAmount);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), _halfAmount);

    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _halfAmount);
    assertEq(yieldVault.balanceOf(address(vault)), _halfAmount);
    assertEq(vault.totalSupply(), _halfAmount);

    vm.stopPrank();
  }

  function testRedeemFullAmountYieldAccrued() external {
    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _amount, alice);

    vm.stopPrank();

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    vm.expectEmit();
    emit Transfer(alice, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, alice, alice, _amount, _amount);

    vault.redeem(vault.maxRedeem(alice), alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _amount);

    assertEq(twabController.balanceOf(address(vault), alice), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), alice), 0);

    assertEq(yieldVault.balanceOf(address(vault)), yieldVault.convertToShares(_yield));
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _yield);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }

  function testRedeemOnBehalf() external {
    uint256 _amount = 1000e18;
    underlyingAsset.mint(bob, _amount);

    vm.startPrank(bob);

    _deposit(underlyingAsset, vault, _amount, bob);
    IERC20(vault).approve(alice, _amount);

    vm.stopPrank();

    vm.startPrank(alice);

    vm.expectEmit();
    emit Transfer(bob, address(0), _amount);

    vm.expectEmit();
    emit Withdraw(alice, bob, bob, _amount, _amount);

    vault.redeem(vault.maxRedeem(bob), bob, bob);

    assertEq(vault.balanceOf(bob), 0);
    assertEq(underlyingAsset.balanceOf(bob), _amount);

    assertEq(twabController.balanceOf(address(vault), bob), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), bob), 0);

    assertEq(yieldVault.balanceOf(address(vault)), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 0);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }
}

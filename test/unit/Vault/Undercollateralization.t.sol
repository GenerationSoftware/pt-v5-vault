// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";

contract VaultUndercollateralizationTest is UnitBaseSetup {
  /* ============ Tests ============ */

  /* ============ Undercollateralization without yield fees accrued ============ */
  function testUndercollateralization() external {
    uint256 _aliceAmount = 15_000_000e18;
    uint256 _aliceAmountUndercollateralized = 7_500_000e18;

    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
    uint256 _bobAmountUndercollateralized = 2_500_000e18;

    underlyingAsset.mint(bob, _bobAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);
    assertEq(vault.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    _deposit(underlyingAsset, vault, _bobAmount, bob);
    assertEq(vault.balanceOf(bob), _bobAmount);

    assertEq(vault.isVaultCollateralized(), true);

    // We burn underlying assets from the YieldVault to trigger the undercollateralization
    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmountUndercollateralized);
    assertEq(vault.maxWithdraw(bob), _bobAmountUndercollateralized);

    vm.stopPrank();

    vm.startPrank(alice);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmountUndercollateralized);

    vm.stopPrank();

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmountUndercollateralized);

    vm.stopPrank();
  }

  /* ============ Undercollateralization with yield fees accrued ============ */
  function testUndercollateralizationWithYieldFees() external {
    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _aliceAmount = 15_000_000e18;
    uint256 _aliceAmountUndercollateralized = 7_800_000e18;

    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
    uint256 _bobAmountUndercollateralized = 2_600_000e18;

    underlyingAsset.mint(bob, _bobAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);
    assertEq(vault.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    _deposit(underlyingAsset, vault, _bobAmount, bob);
    assertEq(vault.balanceOf(bob), _bobAmount);

    assertEq(vault.isVaultCollateralized(), true);

    // We accrue yield
    uint256 _yield = 400_000e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    // And increase yield fee balance
    vault.increaseYieldFeeBalance(_yield);

    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmountUndercollateralized);
    assertEq(vault.maxWithdraw(bob), _bobAmountUndercollateralized);

    vm.stopPrank();

    vm.startPrank(alice);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmountUndercollateralized);

    vm.stopPrank();

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmountUndercollateralized);

    vm.stopPrank();
  }
}

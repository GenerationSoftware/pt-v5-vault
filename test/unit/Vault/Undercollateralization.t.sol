// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;
import { console2 } from "forge-std/Test.sol";
import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";

contract VaultUndercollateralizationTest is UnitBaseSetup {
  /* ============ Tests ============ */

  /* ============ Undercollateralization without yield fees accrued ============ */
  function testUndercollateralization() external {
    uint256 _aliceAmount = 15_000_000e18;
    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
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

    /**
     * Vault shares are still collateralized by YieldVault shares,
     * only the YieldVault shares are not collateralized by the correct amount of underlying assets.
     * So `maxWithdraw` still "think" that Alice and Bob can withdraw their full deposit.
     */
    assertEq(vault.maxWithdraw(alice), _aliceAmount);
    assertEq(vault.maxWithdraw(bob), _bobAmount);

    vm.stopPrank();

    vm.startPrank(alice);

    vault.withdraw(yieldVault.maxWithdraw(address(vault)), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), 10_000_000e18);

    vm.stopPrank();

    // The Vault deposits are now backed by 0 underlying assets, so Bob can't withdraw
    assertEq(yieldVault.maxWithdraw(address(vault)), 0);
  }

  /* ============ Undercollateralization with yield fees accrued ============ */
  function testUndercollateralizationWithYieldFees() external {
    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _aliceAmount = 15_000_000e18;
    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
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

    // And mint yield fees
    vault.mintYieldFees(_yield);

    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmount);
    assertEq(vault.maxWithdraw(bob), _bobAmount);

    vm.stopPrank();

    vm.startPrank(alice);

    vault.withdraw(yieldVault.maxWithdraw(address(vault)), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), 10_000_000e18);

    vm.stopPrank();

    assertEq(yieldVault.maxWithdraw(address(vault)), 0);
  }
}

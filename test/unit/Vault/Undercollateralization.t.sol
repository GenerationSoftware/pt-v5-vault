// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";
import "src/Vault.sol";

contract VaultUndercollateralizationTest is UnitBaseSetup {
  /* ============ Events ============ */

  event RecordedExchangeRate(uint256 exchangeRate);

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

    assertEq(vault.totalSupply(), 0);
  }

  /* ============ Undercollateralization exchange rate reset ============ */
  function testUndercollateralizationExchangeRateReset() external {
    uint256 _aliceAmount = 20_000_000e18;
    uint256 _aliceAmountUndercollateralized = 10_000_000e18;

    underlyingAsset.mint(alice, _aliceAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);
    assertEq(vault.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    assertEq(vault.isVaultCollateralized(), true);

    // We burn underlying assets from the YieldVault to trigger the undercollateralization
    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmountUndercollateralized);

    vm.startPrank(alice);

    vm.expectEmit();
    emit RecordedExchangeRate(5e17); // 50%

    // Trigger recorded exchange rate by depositing 0
    vault.deposit(0, alice);

    // After the next withdraw, there will be no assets left in the vault, so the exchange rate should be reset after the shares are burned
    vm.expectEmit();
    emit RecordedExchangeRate(1e18); // 100%

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmountUndercollateralized);
    assertEq(vault.totalSupply(), 0);

    vm.stopPrank();
  }

  /* ============ Undercollateralization with yield accrued ============ */
  function testUndercollateralizationWithYield() external {
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

    vm.stopPrank();
    assertEq(vault.balanceOf(bob), _bobAmount);

    assertEq(vault.isVaultCollateralized(), true);

    // We accrue yield
    uint256 _yield = 400_000e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmountUndercollateralized);
    assertEq(vault.maxWithdraw(bob), _bobAmountUndercollateralized);

    vm.startPrank(alice);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmountUndercollateralized);

    vm.stopPrank();

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmountUndercollateralized);

    vm.stopPrank();

    assertEq(vault.totalSupply(), 0);
  }

  function testUndercollateralizationWithYieldFeesCaptured() external {
    _setLiquidationPair();
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

    vm.stopPrank();

    assertEq(vault.isVaultCollateralized(), true);

    // We accrue yield...
    uint256 _yield = 400_000e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    // ...and liquidate it
    prizeToken.mint(address(this), type(uint256).max);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    _liquidate(liquidationRouter, liquidationPair, prizeToken, _liquidatedYield, address(this));

    assertEq(vault.balanceOf(address(this)), _liquidatedYield);

    assertEq(vault.availableYieldBalance(), 0);
    assertEq(vault.availableYieldFeeBalance(), 0);

    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    uint256 _yieldFeeShares = vault.yieldFeeTotalSupply();

    vm.expectRevert(abi.encodeWithSelector(VaultUnderCollateralized.selector));
    vault.mintYieldFee(_yieldFeeShares, address(this));

    vm.startPrank(bob);

    _bobAmount = _getMaxWithdraw(bob, vault, yieldVault);
    assertApproxEqAbs(vault.maxWithdraw(bob), _bobAmount, 2382812);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertApproxEqAbs(underlyingAsset.balanceOf(bob), _bobAmount, 2382812);

    vm.stopPrank();

    vm.startPrank(alice);

    _aliceAmount = _getMaxWithdraw(alice, vault, yieldVault);
    assertApproxEqAbs(vault.maxWithdraw(alice), _aliceAmount, 2382812);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertApproxEqAbs(underlyingAsset.balanceOf(alice), _aliceAmount, 2382812);

    vm.stopPrank();

    uint256 _thisAmount = _getMaxWithdraw(address(this), vault, yieldVault);
    assertApproxEqAbs(vault.maxWithdraw(address(this)), _thisAmount, 280000);

    vault.withdraw(vault.maxWithdraw(address(this)), address(this), address(this));
    assertApproxEqAbs(underlyingAsset.balanceOf(address(this)), _thisAmount, 280000);
    assertEq(vault.totalSupply(), 0);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

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

    assertEq(vault.isVaultCollateralized(), false);

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmountUndercollateralized);

    vm.stopPrank();

    // The Vault is now back to his initial state with no more shares,
    // so the exchange rate is reset and the Vault is no longer undercollateralized
    assertEq(vault.isVaultCollateralized(), true);
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

    assertEq(vault.isVaultCollateralized(), true);

    // We burn underlying assets from the YieldVault to trigger the undercollateralization
    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.exchangeRate(), 5e17); // 50%
    assertEq(vault.isVaultCollateralized(), false);

    assertEq(vault.maxWithdraw(alice), _aliceAmountUndercollateralized);

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

    // We burn underlying assets from the YieldVault to trigger the undercollateralization
    underlyingAsset.burn(address(yieldVault), 10_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    uint256 _yieldFeeShares = vault.yieldFeeShares();

    // The Vault is now undercollateralized so we can't mint the yield fee
    vm.expectRevert(abi.encodeWithSelector(VaultUnderCollateralized.selector));
    vault.mintYieldFee(_yieldFeeShares);

    vm.startPrank(bob);

    // We lose in precision because the Vault is undercollateralized
    // and the exchange rate is below 1e18 and rounded down
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
    assertApproxEqAbs(vault.maxWithdraw(address(this)), _thisAmount, 2440000);

    vault.withdraw(vault.maxWithdraw(address(this)), address(this), address(this));
    assertApproxEqAbs(underlyingAsset.balanceOf(address(this)), _thisAmount, 2440000);

    assertEq(vault.totalSupply(), 0);
    assertApproxEqAbs(underlyingAsset.balanceOf(address(yieldVault)), 0, 2440000);
  }

  function testPartialUndercollateralizationWithYieldFeesCaptured() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(address(this));

    uint256 _aliceAmount = 1000e18;
    underlyingAsset.mint(alice, _aliceAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);
    assertEq(vault.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    assertEq(vault.isVaultCollateralized(), true);

    // We accrue yield...
    uint256 _yield = 20e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    assertEq(vault.availableYieldBalance(), 20e18);
    assertEq(vault.availableYieldFeeBalance(), 2e18);

    // ...and liquidate it
    prizeToken.mint(bob, type(uint256).max);

    vm.startPrank(bob);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    _liquidate(liquidationRouter, liquidationPair, prizeToken, _liquidatedYield, bob);

    vm.stopPrank();

    assertEq(vault.balanceOf(bob), _liquidatedYield);

    assertEq(vault.availableYieldBalance(), 0);
    assertEq(vault.availableYieldFeeBalance(), 0);

    // We burn 1e18 underlying assets from the YieldVault to trigger the partial undercollateralization
    underlyingAsset.burn(address(yieldVault), 1e18);

    assertEq(vault.isVaultCollateralized(), true);

    uint256 _yieldFeeShares = vault.yieldFeeShares();

    // The Vault is now partially undercollateralized so we can't mint the yield fee
    vm.expectRevert(
      abi.encodeWithSelector(
        YieldFeeGTAvailableYield.selector,
        vault.convertToAssets(_yieldFeeShares),
        yieldVault.maxWithdraw(address(vault)) - vault.convertToAssets(vault.totalSupply())
      )
    );

    vault.mintYieldFee(_yieldFeeShares);

    vm.startPrank(alice);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);

    assertEq(underlyingAsset.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);

    assertEq(underlyingAsset.balanceOf(bob), _yield - _yieldFeeShares);

    vm.stopPrank();

    assertEq(vault.totalSupply(), 0);
  }
}

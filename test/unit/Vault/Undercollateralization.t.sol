// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

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

    assertEq(vault.isVaultCollateralized(), false);

    vm.startPrank(bob);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmountUndercollateralized);

    vm.stopPrank();

    // The Vault is now back to his initial state with no more shares
    assertEq(vault.isVaultCollateralized(), true);
    assertEq(vault.totalSupply(), 0);
  }

  function testUndercollateralizationYieldVaultReCollateralized() external {
    uint256 _aliceAmount = 15_000_000e18;

    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
    uint256 _bobUndercollateralizedAmount = 2_500_000e18;

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
    uint256 _undercollateralizedAmount = 10_000_000e18;
    underlyingAsset.burn(address(yieldVault), _undercollateralizedAmount);

    assertEq(vault.isVaultCollateralized(), false);

    // Bob decides to take the loss and withdraw his shares of the deposit
    assertEq(vault.maxWithdraw(bob), _bobUndercollateralizedAmount);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobUndercollateralizedAmount);

    vm.stopPrank();

    // Funds are returned to the YieldVault
    underlyingAsset.mint(address(yieldVault), _undercollateralizedAmount);

    assertEq(vault.isVaultCollateralized(), true);

    vm.startPrank(alice);

    // Alice decided to wait and can now withdraw her full amount
    assertEq(vault.maxWithdraw(alice), _aliceAmount);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    assertEq(vault.isVaultCollateralized(), true);
    assertEq(vault.totalSupply(), 0);
  }

  function testUndercollateralizationYieldVaultAssetsUnavailable() external {
    uint256 _aliceAmount = 15_000_000e18;

    underlyingAsset.mint(alice, _aliceAmount);

    uint256 _bobAmount = 5_000_000e18;
    uint256 _bobWithdrawableAmount = 2_500_000e18;

    underlyingAsset.mint(bob, _bobAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);
    assertEq(vault.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    _deposit(underlyingAsset, vault, _bobAmount, bob);
    assertEq(vault.balanceOf(bob), _bobAmount);

    // Bob can redeem his full deposits and shares
    assertEq(vault.maxRedeem(bob), _bobAmount);
    assertEq(vault.maxWithdraw(bob), _bobAmount);
    assertEq(vault.previewRedeem(_bobAmount), _bobAmount);
    assertEq(vault.previewWithdraw(_bobAmount), _bobAmount);

    assertEq(vault.isVaultCollateralized(), true);
    assertEq(yieldVault.totalSupply(), 20_000_000e18);

    // 10_000_000e18 underlying assets have been lended and are currently unavailable in the YieldVault
    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(yieldVault)),
      abi.encode(10_000_000e18)
    );

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)),
      abi.encode(10_000_000e18)
    );

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxWithdraw.selector, address(vault)),
      abi.encode(10_000_000e18)
    );

    assertEq(yieldVault.maxRedeem(address(vault)), 10_000_000e18);
    assertEq(yieldVault.totalSupply(), 20_000_000e18);

    assertEq(vault.isVaultCollateralized(), false);

    // Bob can redeem his full shares but will only receive back half his deposit
    assertEq(vault.maxRedeem(bob), _bobAmount);
    assertEq(vault.maxWithdraw(bob), _bobWithdrawableAmount);

    assertEq(vault.previewRedeem(vault.maxRedeem(bob)), _bobWithdrawableAmount);
    assertEq(vault.previewWithdraw(vault.maxWithdraw(bob)), _bobAmount);

    vault.redeem(vault.maxRedeem(bob), bob, bob);

    // Bob has withdrawn 2_500_000e18 assets and burnt all his shares
    assertEq(underlyingAsset.balanceOf(bob), _bobWithdrawableAmount);
    assertEq(vault.balanceOf(bob), 0);
    assertEq(vault.maxWithdraw(bob), 0);

    // Only 2_500_000e18 YieldVault shares have been burnt
    uint256 _availableUnderlyingAssets = 20_000_000e18 - 2_500_000e18;

    assertEq(yieldVault.balanceOf(address(vault)), _availableUnderlyingAssets);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), _availableUnderlyingAssets);

    vm.stopPrank();

    // Funds are available again in the YieldVault
    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC20.balanceOf.selector, address(yieldVault)),
      abi.encode(_availableUnderlyingAssets)
    );

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)),
      abi.encode(_availableUnderlyingAssets)
    );

    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxWithdraw.selector, address(vault)),
      abi.encode(_availableUnderlyingAssets)
    );

    assertEq(vault.isVaultCollateralized(), true);

    vm.startPrank(alice);

    // Alice decided to wait and can now withdraw her full amount
    assertEq(vault.maxWithdraw(alice), _aliceAmount);

    vault.withdraw(vault.maxWithdraw(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    assertEq(vault.isVaultCollateralized(), true);
    assertEq(vault.totalSupply(), 0);

    // All Vault shares have been burnt but the Vault still owns 2_500_000e18 YieldVault shares
    assertEq(yieldVault.balanceOf(address(vault)), 2_500_000e18);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 2_500_000e18);
  }

  function testUndercollateralizationYieldVaultEmpty() external {
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

    // We burn all the underlying assets from the YieldVault to trigger the undercollateralization
    uint256 _undercollateralizedAmount = 20_000_000e18;
    underlyingAsset.burn(address(yieldVault), _undercollateralizedAmount);

    assertEq(vault.isVaultCollateralized(), false);

    uint256 _bobMaxWithdraw = vault.maxWithdraw(bob);

    // Bob can't withdraw any assets
    assertEq(_bobMaxWithdraw, 0);

    vm.expectRevert(abi.encodeWithSelector(Vault.WithdrawZeroAssets.selector));

    vault.withdraw(_bobMaxWithdraw, bob, bob);

    vm.stopPrank();

    vm.startPrank(alice);

    uint256 _aliceMaxWithdraw = vault.maxWithdraw(alice);

    // Alice can't withdraw any assets
    assertEq(_aliceMaxWithdraw, 0);

    vm.expectRevert(abi.encodeWithSelector(Vault.WithdrawZeroAssets.selector));

    vault.withdraw(_aliceMaxWithdraw, alice, alice);

    underlyingAsset.mint(alice, _aliceAmount);

    // Alice can't deposit into an undercollateralized vault
    vm.expectRevert(abi.encodeWithSelector(Vault.VaultUnderCollateralized.selector));

    vault.deposit(_aliceAmount, alice);

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
    vm.expectRevert(abi.encodeWithSelector(Vault.VaultUnderCollateralized.selector));
    vault.mintYieldFee(_yieldFeeShares);

    vm.startPrank(bob);

    _bobAmount = _getMaxWithdraw(bob, vault, yieldVault);
    assertEq(vault.maxWithdraw(bob), _bobAmount);

    vault.withdraw(vault.maxWithdraw(bob), bob, bob);
    assertEq(underlyingAsset.balanceOf(bob), _bobAmount);

    vm.stopPrank();

    vm.startPrank(alice);

    _aliceAmount = _getMaxWithdraw(alice, vault, yieldVault);
    assertEq(vault.maxWithdraw(alice), _aliceAmount);

    // Due to the undercollateralization `maxWithdraw` rounds down
    // and Alice would still own 1 Vault share after withdrawing
    // We use `redeem` instead to withdraw the full amount and burn all shares
    vault.redeem(vault.maxRedeem(alice), alice, alice);
    assertEq(underlyingAsset.balanceOf(alice), _aliceAmount);

    vm.stopPrank();

    uint256 _thisAmount = _getMaxWithdraw(address(this), vault, yieldVault);
    assertEq(vault.maxWithdraw(address(this)), _thisAmount);

    vault.withdraw(vault.maxWithdraw(address(this)), address(this), address(this));
    assertEq(underlyingAsset.balanceOf(address(this)), _thisAmount);

    assertApproxEqAbs(vault.totalSupply(), 0, 2);
    assertApproxEqAbs(underlyingAsset.balanceOf(address(yieldVault)), 0, 1);
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
        Vault.YieldFeeGTAvailableYield.selector,
        vault.convertToAssets(_yieldFeeShares),
        yieldVault.maxWithdraw(address(vault)) - vault.convertToAssets(vault.totalSupply())
      )
    );

    vault.mintYieldFee(_yieldFeeShares);

    vm.startPrank(alice);

    assertEq(vault.maxWithdraw(alice), _aliceAmount);

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

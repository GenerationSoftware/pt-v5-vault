// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup, IERC20 } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

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

  function testWithdrawFullAmountYieldLiquidated() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _aliceAmount = 1000e18;
    underlyingAsset.mint(alice, _aliceAmount);

    vm.startPrank(alice);

    _deposit(underlyingAsset, vault, _aliceAmount, alice);

    vm.stopPrank();

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(bob);

    prizeToken.mint(bob, type(uint256).max);

    // We liquidate the accrued yield
    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    (uint256 _bobPrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      bob
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(bob), _bobPrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, YIELD_FEE_PERCENTAGE);
    uint256 _bobAmount = _yield - _yieldFeeShares;

    // Bob now owns 9e18 Vault shares
    assertEq(vault.balanceOf(bob), _yield - _yieldFeeShares);

    // 1e18 have been allocated as yield fee
    assertEq(vault.yieldFeeShares(), _yieldFeeShares);
    assertEq(_yield, _liquidatedYield + _yieldFeeShares);

    vm.stopPrank();

    // The Vault is still collateralized, so users can withdraw their full deposit
    assertEq(vault.maxWithdraw(bob), _bobAmount);
    assertEq(vault.maxWithdraw(alice), _aliceAmount);

    // We burn the accrued yield to set the Vault in an undercollateralized state
    underlyingAsset.burn(address(yieldVault), _yield);

    // The Vault is now undercollateralized, so users can withdraw their share of the deposits
    assertEq(vault.maxWithdraw(bob), _getMaxWithdraw(bob, vault, yieldVault));
    assertEq(vault.maxWithdraw(alice), _getMaxWithdraw(alice, vault, yieldVault));

    vm.startPrank(alice);

    uint256 _aliceWithdrawableAmount = vault.maxWithdraw(alice);
    vault.withdraw(_aliceWithdrawableAmount, alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _aliceWithdrawableAmount);

    vm.stopPrank();

    vm.startPrank(bob);

    uint256 _bobWithdrawableAmount = vault.maxWithdraw(bob);
    vault.withdraw(_bobWithdrawableAmount, bob, bob);

    assertEq(vault.balanceOf(bob), 0);
    assertEq(underlyingAsset.balanceOf(bob), _bobWithdrawableAmount);

    assertEq(vault.totalSupply(), 0);
    assertEq(underlyingAsset.balanceOf(address(yieldVault)), 0);

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

  /* ============ Withdraw - Errors ============ */

  function testWithdrawMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectRevert(
      abi.encodeWithSelector(WithdrawMoreThanMax.selector, alice, _amount + 1, _amount)
    );

    vault.withdraw(_amount + 1, alice, alice);

    vm.stopPrank();
  }

  function testWithdrawZeroAssets() external {
    vm.startPrank(alice);

    vm.expectRevert(abi.encodeWithSelector(WithdrawZeroAssets.selector));

    vault.withdraw(0, alice, alice);

    vm.stopPrank();
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

  /* ============ Redeem - Errors ============ */

  function testRedeemMoreThanMax() external {
    vm.startPrank(alice);

    uint256 _amount = 1000e18;
    underlyingAsset.mint(alice, _amount);
    uint256 _shares = _deposit(underlyingAsset, vault, _amount, alice);

    vm.expectRevert(
      abi.encodeWithSelector(RedeemMoreThanMax.selector, alice, _shares + 1, _shares)
    );
    vault.redeem(_shares + 1, alice, alice);

    vm.stopPrank();
  }

  function testRedeemZeroShares() external {
    vm.startPrank(alice);

    vm.expectRevert(abi.encodeWithSelector(WithdrawZeroAssets.selector));

    vault.redeem(0, alice, alice);

    vm.stopPrank();
  }
}

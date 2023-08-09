// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

contract VaultLiquidateTest is UnitBaseSetup {
  /* ============ Events ============ */
  event MintYieldFee(address indexed caller, address indexed recipient, uint256 shares);

  /* ============ Without fees ============ */
  function testLiquidateFullYield() external {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _yield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    assertEq(vault.balanceOf(alice), _yield);
    assertEq(vault.liquidatableBalanceOf(address(vault)), 0);
    assertEq(vault.availableYieldBalance(), 0);
    assertEq(vault.availableYieldFeeBalance(), 0);

    vm.stopPrank();
  }

  function testLiquidateQuarterYield() external {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatedYield = 2.5e18;
    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.liquidatableBalanceOf(address(vault)), _yield - _liquidatedYield);
    assertEq(vault.availableYieldBalance(), _yield - _liquidatedYield);
    assertEq(vault.availableYieldFeeBalance(), 0);

    vm.stopPrank();
  }

  /* ============ With fees ============ */
  function testLiquidateFullYieldWithFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.yieldFeeShares(), _yieldFeeShares);
    assertEq(_yield, _liquidatedYield + _yieldFeeShares);

    assertEq(vault.liquidatableBalanceOf(address(vault)), 0);
    assertEq(vault.availableYieldBalance(), 0);
    assertEq(vault.availableYieldFeeBalance(), 0);

    vm.stopPrank();
  }

  function testLiquidateFullYieldWithFeesLowDecimals() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(LOW_YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e2;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e2;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e2);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, LOW_YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.yieldFeeShares(), _yieldFeeShares);
    assertEq(_yield, _liquidatedYield + _yieldFeeShares);

    assertEq(vault.liquidatableBalanceOf(address(vault)), 0);
    assertEq(vault.availableYieldBalance(), 0);
    assertEq(vault.availableYieldFeeBalance(), 0);

    vm.stopPrank();
  }

  function testLiquidateQuarterYieldWithFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;

    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault)) / 4;

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);

    uint256 _availableYieldBalance = _getAvailableYieldBalance(
      _yield,
      _liquidatedYield,
      _yieldFeeShares
    );

    assertEq(
      vault.liquidatableBalanceOf(address(vault)),
      _getLiquidatableBalanceOf(_availableYieldBalance, YIELD_FEE_PERCENTAGE)
    );

    assertEq(vault.availableYieldBalance(), _availableYieldBalance);
    assertEq(
      vault.availableYieldFeeBalance(),
      _getAvailableYieldFeeBalance(_availableYieldBalance, YIELD_FEE_PERCENTAGE)
    );

    vm.stopPrank();
  }

  function testLiquidateQuarterYieldWithFeesLowDecimals() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(LOW_YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e2;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e2;

    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e2);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, LOW_YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);

    uint256 _availableYieldBalance = _getAvailableYieldBalance(
      _yield,
      _liquidatedYield,
      _yieldFeeShares
    );

    assertEq(
      vault.liquidatableBalanceOf(address(vault)),
      _getLiquidatableBalanceOf(_availableYieldBalance, LOW_YIELD_FEE_PERCENTAGE)
    );

    assertEq(vault.availableYieldBalance(), _availableYieldBalance);
    assertEq(
      vault.availableYieldFeeBalance(),
      _getAvailableYieldFeeBalance(_availableYieldBalance, LOW_YIELD_FEE_PERCENTAGE)
    );

    vm.stopPrank();
  }

  function testLiquidateAndMintFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(bob);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    _liquidate(liquidationRouter, liquidationPair, prizeToken, _liquidatedYield, alice);

    vm.stopPrank();

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(bob), 0);

    assertEq(vault.totalSupply(), _amount + _liquidatedYield);
    assertEq(vault.yieldFeeShares(), _yieldFeeShares);

    vm.expectEmit();
    emit MintYieldFee(address(this), bob, _yieldFeeShares);

    vault.mintYieldFee(_yieldFeeShares);

    assertEq(vault.balanceOf(bob), _yieldFeeShares);

    assertEq(vault.totalSupply(), _amount + _liquidatedYield + _yieldFeeShares);
    assertEq(vault.yieldFeeShares(), 0);
  }

  /* ============ Liquidate - Errors ============ */
  function testLiquidateYieldVaultUndercollateralized() public {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    underlyingAsset.burn(address(yieldVault), 100e18);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(abi.encodeWithSelector(VaultUnderCollateralized.selector));

    vault.liquidate(address(this), address(prizeToken), 1e18, address(vault), 1e18);

    vm.stopPrank();
  }

  function testLiquidateCallerNotLP() public {
    _setLiquidationPair();

    vm.startPrank(bob);

    vm.expectRevert(
      abi.encodeWithSelector(LiquidationCallerNotLP.selector, bob, address(liquidationPair))
    );

    vault.liquidate(address(this), address(prizeToken), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateTokenInNotPrizeToken() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(
        LiquidationTokenInNotPrizeToken.selector,
        address(0),
        address(prizeToken)
      )
    );

    vault.liquidate(address(this), address(0), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateTokenOutNotVaultShare() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(LiquidationTokenOutNotVaultShare.selector, address(0), address(vault))
    );

    vault.liquidate(address(this), address(prizeToken), 0, address(0), 0);

    vm.stopPrank();
  }

  function testLiquidateAmountOutNotZero() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(abi.encodeWithSelector(LiquidationAmountOutZero.selector));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateAmountGTAvailableYield() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(LiquidationAmountOutGTYield.selector, type(uint256).max, 0)
    );

    vault.liquidate(address(this), address(prizeToken), 0, address(vault), type(uint256).max);

    vm.stopPrank();
  }

  function testLiquidateAmountOutGTMaxMint() public {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _amountOut = type(uint104).max;
    _accrueYield(underlyingAsset, yieldVault, _amountOut);

    vm.startPrank(address(alice));

    prizeToken.mint(alice, type(uint256).max);
    prizeToken.approve(address(this), type(uint256).max);

    vm.stopPrank();

    uint256 _amountIn = liquidationPair.computeExactAmountIn(_amountOut);

    IERC20(address(prizeToken)).transferFrom(alice, address(prizePool), _amountIn);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(MintMoreThanMax.selector, alice, _amountOut, type(uint96).max)
    );

    vault.liquidate(alice, address(prizeToken), _amountIn, address(vault), _amountOut);

    vm.stopPrank();
  }

  /* ============ MintYieldFee - Errors ============ */
  function testMintYieldFeeGTYieldFeeShares() public {
    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    _accrueYield(underlyingAsset, yieldVault, 10e18);

    vm.expectRevert(abi.encodeWithSelector(YieldFeeGTAvailableShares.selector, 10e18, 0));
    vault.mintYieldFee(10e18);
  }

  function testMintYieldFeeMoreThanMax() public {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(bob);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e18;
    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatableYield = vault.liquidatableBalanceOf(address(vault));

    _liquidate(liquidationRouter, liquidationPair, prizeToken, _liquidatableYield, alice);

    vm.stopPrank();

    vm.startPrank(bob);

    underlyingAsset.mint(bob, vault.maxDeposit(bob));
    underlyingAsset.approve(address(vault), vault.maxDeposit(bob));

    vault.deposit(vault.maxDeposit(bob), bob);

    vm.expectRevert(abi.encodeWithSelector(MintMoreThanMax.selector, bob, 1e18, 0));

    vault.mintYieldFee(1e18);

    vm.stopPrank();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { UnitBaseSetup } from "test/utils/UnitBaseSetup.t.sol";

contract VaultLiquidateTest is UnitBaseSetup {
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
    assertEq(vault.availableBalanceOf(address(vault)), 0);
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
    assertEq(vault.availableBalanceOf(address(vault)), _yield - _liquidatedYield);
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

    uint256 _liquidatedYield = vault.availableBalanceOf(address(vault));

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeAmount = _getYieldFeeAmount(_yield, YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.balanceOf(address(this)), _amount + _yieldFeeAmount);
    assertEq(_yield, _liquidatedYield + _yieldFeeAmount);

    assertEq(vault.availableBalanceOf(address(vault)), 0);
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

    uint256 _liquidatedYield = vault.availableBalanceOf(address(vault));

    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeAmount = _getYieldFeeAmount(_yield, LOW_YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.balanceOf(address(this)), _amount + _yieldFeeAmount);
    assertEq(_yield, _liquidatedYield + _yieldFeeAmount);

    assertEq(vault.availableBalanceOf(address(vault)), 0);
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
    uint256 _yieldFeeAmount = _getYieldFeeAmount(_yield, YIELD_FEE_PERCENTAGE);
    uint256 _liquidableYield = _yield - _yieldFeeAmount;

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

    uint256 _yieldFeeAmountLiquidated = _getYieldFeeAmountLiquidated(
      _yield,
      YIELD_FEE_PERCENTAGE,
      _liquidatedYield,
      _liquidableYield
    );

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.balanceOf(address(this)), _amount + _yieldFeeAmountLiquidated);

    uint256 _availableYieldBalance = _yield - (_liquidatedYield + _yieldFeeAmountLiquidated);
    uint256 _availableYieldFeeBalance = _getYieldFeeAmount(
      _availableYieldBalance,
      YIELD_FEE_PERCENTAGE
    );

    assertEq(
      vault.availableBalanceOf(address(vault)),
      _availableYieldBalance - _availableYieldFeeBalance
    );
    assertEq(vault.availableYieldBalance(), _availableYieldBalance);
    assertEq(vault.availableYieldFeeBalance(), _availableYieldFeeBalance);

    vm.stopPrank();
  }

  function testLiquidateQuarterYieldWithFeesLowDecimals() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(LOW_YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e2;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount, address(this));

    uint256 _yield = 10e2;
    uint256 _yieldFeeAmount = _getYieldFeeAmount(_yield, LOW_YIELD_FEE_PERCENTAGE);
    uint256 _liquidableYield = _yield - _yieldFeeAmount;

    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e2);

    uint256 _liquidatedYield = 2.5e2;
    (uint256 _alicePrizeTokenBalanceBefore, uint256 _prizeTokenContributed) = _liquidate(
      liquidationRouter,
      liquidationPair,
      prizeToken,
      _liquidatedYield,
      alice
    );

    assertEq(prizeToken.balanceOf(address(prizePool)), _prizeTokenContributed);
    assertEq(prizeToken.balanceOf(alice), _alicePrizeTokenBalanceBefore - _prizeTokenContributed);

    uint256 _yieldFeeAmountLiquidated = _getYieldFeeAmountLiquidated(
      _yield,
      LOW_YIELD_FEE_PERCENTAGE,
      _liquidatedYield,
      _liquidableYield
    );

    assertEq(vault.balanceOf(alice), _liquidatedYield);
    assertEq(vault.balanceOf(address(this)), _amount + _yieldFeeAmountLiquidated);

    uint256 _availableYieldBalance = _yield - (_liquidatedYield + _yieldFeeAmountLiquidated);
    uint256 _availableYieldFeeBalance = _getYieldFeeAmount(
      _availableYieldBalance,
      LOW_YIELD_FEE_PERCENTAGE
    );

    assertEq(
      vault.availableBalanceOf(address(vault)),
      _availableYieldBalance - _availableYieldFeeBalance
    );
    assertEq(vault.availableYieldBalance(), _availableYieldBalance);
    assertEq(vault.availableYieldFeeBalance(), _availableYieldFeeBalance);

    vm.stopPrank();
  }

  /* ============ Errors ============ */
  function testLiquidateCallerNotLP() public {
    _setLiquidationPair();

    vm.startPrank(bob);

    vm.expectRevert(bytes("Vault/caller-not-LP"));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateTokenInNotPrizeToken() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/tokenIn-not-prizeToken"));
    vault.liquidate(address(this), address(0), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateTokenOutNotVaultShare() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/tokenOut-not-vaultShare"));
    vault.liquidate(address(this), address(prizeToken), 0, address(0), 0);

    vm.stopPrank();
  }

  function testLiquidateAmountOutNotZero() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/amountOut-not-zero"));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateAmountGTAvailableYield() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/amount-gt-available-yield"));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), type(uint256).max);

    vm.stopPrank();
  }
}

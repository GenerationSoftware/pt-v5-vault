// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup } from "../../utils/UnitBaseSetup.t.sol";
import "../../../src/Vault.sol";

contract VaultLiquidateTest is UnitBaseSetup {
  /* ============ Events ============ */
  event MintYieldFee(address indexed caller, address indexed recipient, uint256 shares);

  /* ============ Without fees ============ */
  function testTransferTokensOut_FullYield() external {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_QuarterYield() external {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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
  function testTransferTokensOut_FullYieldWithFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_FullYieldWithFeesLowDecimals() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(LOW_YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e2;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_QuarterYieldWithFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_QuarterYieldWithFeesLowDecimals() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(LOW_YIELD_FEE_PERCENTAGE);

    uint256 _amount = 1000e2;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_AndMintFees() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(bob);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

  function testTransferTokensOut_AndMintFees_YieldVaultMaxMintReached() external {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(bob);

    uint256 _yield = 10e18;
    uint256 _amount = type(uint112).max - _yield;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

    _accrueYield(underlyingAsset, yieldVault, _yield);

    vm.startPrank(alice);

    prizeToken.mint(alice, 1000e18);

    uint256 _liquidatedYield = vault.liquidatableBalanceOf(address(vault));

    // Yield Vault has reached its max mint limit
    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.maxMint.selector, address(vault)),
      abi.encode(type(uint104).max)
    );

    // Yield has accrued, so despite the max mint limit reached,
    // we should still be able to liquidate prize tokens in exchange of Vault shares
    _liquidate(liquidationRouter, liquidationPair, prizeToken, _liquidatedYield, alice);

    assertEq(vault.balanceOf(alice), _liquidatedYield);

    vault.withdraw(_liquidatedYield, alice, alice);

    assertEq(vault.balanceOf(alice), 0);
    assertEq(underlyingAsset.balanceOf(alice), _liquidatedYield);

    vm.stopPrank();

    uint256 _yieldFeeShares = _getYieldFeeShares(_liquidatedYield, YIELD_FEE_PERCENTAGE);

    assertEq(vault.balanceOf(bob), 0);

    // _yieldFeeShares has not been minted yet, so totatSupply is type(uint112).max - _yield
    assertEq(vault.totalSupply(), _amount);
    assertEq(vault.yieldFeeShares(), _yieldFeeShares);

    vm.expectEmit();
    emit MintYieldFee(address(this), bob, _yieldFeeShares);

    vault.mintYieldFee(_yieldFeeShares);

    assertEq(vault.balanceOf(bob), _yieldFeeShares);

    assertEq(vault.totalSupply(), _amount + _yieldFeeShares);
    assertEq(vault.yieldFeeShares(), 0);

    vm.startPrank(bob);

    vault.withdraw(_yieldFeeShares, bob, bob);

    assertEq(vault.totalSupply(), _amount);

    assertEq(vault.balanceOf(bob), 0);
    assertEq(underlyingAsset.balanceOf(bob), _yieldFeeShares);

    vm.stopPrank();
  }

  /* ============ Liquidate - Errors ============ */
  function testTransferTokensOut_YieldVaultUndercollateralized() public {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

    underlyingAsset.burn(address(yieldVault), 100e18);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(abi.encodeWithSelector(Vault.VaultUnderCollateralized.selector));

    vault.transferTokensOut(address(this), address(this), address(vault), 1e18);

    vm.stopPrank();
  }

  function testTransferTokensOut_CallerNotLP() public {
    _setLiquidationPair();

    vm.startPrank(bob);

    vm.expectRevert(
      abi.encodeWithSelector(Vault.CallerNotLP.selector, bob, address(liquidationPair))
    );

    vault.transferTokensOut(address(this), address(this), address(vault), 1e18);

    vm.stopPrank();
  }

  function testVerifyTokensIn_success() public {
    _setLiquidationPair();

    vm.mockCall(
      address(prizePool),
      abi.encodeCall(PrizePool.contributePrizeTokens, (address(vault), 1e18)),
      abi.encode(0)
    );

    vm.startPrank(address(liquidationPair));
    vault.verifyTokensIn(address(prizeToken), 1e18, "");
    vm.stopPrank();
  }

  function testVerifyTokensIn_CallerNotLP() public {
    _setLiquidationPair();

    vm.expectRevert(
      abi.encodeWithSelector(Vault.CallerNotLP.selector, address(bob), address(liquidationPair))
    );

    vm.startPrank(address(bob));
    vault.verifyTokensIn(address(0), 1e18, "");
    vm.stopPrank();
  }

  function testVerifyTokensIn_TokenInNotPrizeToken() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(
        Vault.LiquidationTokenInNotPrizeToken.selector,
        address(0),
        address(prizeToken)
      )
    );

    vault.verifyTokensIn(address(0), 1e18, "");

    vm.stopPrank();
  }

  function testTransferTokensOut_TokenOutNotVaultShare() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(
        Vault.LiquidationTokenOutNotVaultShare.selector,
        address(0),
        address(vault)
      )
    );

    vault.transferTokensOut(address(this), address(this), address(0), 0);

    vm.stopPrank();
  }

  function testTransferTokensOut_AmountOutNotZero() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(abi.encodeWithSelector(Vault.LiquidationAmountOutZero.selector));

    vault.transferTokensOut(address(this), address(this), address(vault), 0);

    vm.stopPrank();
  }

  function testTransferTokensOut_AmountGTAvailableYield() public {
    _setLiquidationPair();

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(
      abi.encodeWithSelector(Vault.LiquidationAmountOutGTYield.selector, type(uint256).max, 0)
    );

    vault.transferTokensOut(address(this), address(this), address(vault), type(uint256).max);

    vm.stopPrank();
  }

  function testTransferTokensOut_AmountOutGTUint112() public {
    _setLiquidationPair();

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

    uint256 _amountOut = type(uint120).max;
    _accrueYield(underlyingAsset, yieldVault, _amountOut);

    vm.startPrank(address(alice));

    prizeToken.mint(alice, type(uint256).max);
    prizeToken.approve(address(this), type(uint256).max);

    vm.stopPrank();

    uint256 _amountIn = liquidationPair.computeExactAmountIn(_amountOut);

    IERC20(address(prizeToken)).transferFrom(alice, address(prizePool), _amountIn);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("SafeCast: value doesn't fit in 112 bits"));

    vault.transferTokensOut(address(this), alice, address(vault), _amountOut);

    vm.stopPrank();
  }

  /* ============ MintYieldFee - Errors ============ */
  function testMintYieldFeeGTYieldFeeShares() public {
    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

    _accrueYield(underlyingAsset, yieldVault, 10e18);

    vm.expectRevert(abi.encodeWithSelector(Vault.YieldFeeGTAvailableShares.selector, 10e18, 0));
    vault.mintYieldFee(10e18);
  }

  function testMintYieldFeeMoreThanMax() public {
    _setLiquidationPair();

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    vault.setYieldFeeRecipient(bob);

    uint256 _amount = 1000e18;

    underlyingAsset.mint(address(this), _amount);
    _sponsor(underlyingAsset, vault, _amount);

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

    vm.expectRevert();

    vault.mintYieldFee(1e18);

    vm.stopPrank();
  }
}

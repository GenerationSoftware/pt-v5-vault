// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UnitBaseSetup, PrizePool, TwabController, ERC20, IERC20, IERC4626 } from "../../utils/UnitBaseSetup.t.sol";
import { IVaultHooks, VaultHooks } from "../../../src/interfaces/IVaultHooks.sol";

import "../../../src/PrizeVault.sol";

contract PrizeVaultTest is UnitBaseSetup {

  /* ============ Events ============ */

  event ClaimerSet(address indexed claimer);

  event LiquidationPairSet(address indexed tokenOut, address indexed liquidationPair);

  event YieldFeeRecipientSet(address indexed yieldFeeRecipient);

  event YieldFeePercentageSet(uint256 yieldFeePercentage);

  /* ============ Constructor ============ */

  function testConstructor() public {
    PrizeVault testVault = new PrizeVault(
      vaultName,
      vaultSymbol,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );

    uint256 assetDecimals = ERC20(address(underlyingAsset)).decimals();

    assertEq(testVault.asset(), address(underlyingAsset));
    assertEq(testVault.name(), vaultName);
    assertEq(testVault.symbol(), vaultSymbol);
    assertEq(testVault.decimals(), assetDecimals);
    assertEq(address(testVault.twabController()), address(twabController));
    assertEq(address(testVault.yieldVault()), address(yieldVault));
    assertEq(address(testVault.prizePool()), address(prizePool));
    assertEq(testVault.claimer(), address(claimer));
    assertEq(testVault.owner(), address(this));
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(abi.encodeWithSelector(PrizeVault.YieldVaultZeroAddress.selector));

    new PrizeVault(
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      IERC4626(address(0)),
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testFailConstructorPrizePoolZero() external {
    // Fails because `prizePool.twabController()` is not callable on the zero address
    new PrizeVault(
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      yieldVault,
      PrizePool(address(0)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testConstructorOwnerZero() external {
    vm.expectRevert(abi.encodeWithSelector(PrizeVault.OwnerZeroAddress.selector));

    new PrizeVault(
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(0)
    );
  }

  function testConstructorClaimerZero() external {
    vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));

    new PrizeVault(
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      yieldVault,
      PrizePool(address(prizePool)),
      address(0),
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  /* ============ External functions ============ */

  /* ============ targetOf ============ */
  function testTargetOf() public {
    _setLiquidationPair();

    address target = vault.targetOf(address(prizeToken));
    assertEq(target, address(prizePool));
  }

  /* ============ Getters ============ */
  function testGetYieldVault() external {
    assertEq(address(vault.yieldVault()), address(yieldVault));
  }

  function testGetLiquidationPair() external {
    vault.setLiquidationPair(address(liquidationPair));
    assertEq(address(vault.liquidationPair()), address(liquidationPair));
  }

  function testGetYieldFeeRecipient() external {
    assertEq(vault.yieldFeeRecipient(), address(this));
  }

  function testGetYieldFeePercentage() external {
    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
  }

  /* ============ Setters ============ */

  /* ============ setClaimer ============ */
  function testSetClaimer() public {
    address _newClaimer = makeAddr("claimer");

    vm.expectEmit(true, true, true, true);
    emit ClaimerSet(_newClaimer);

    vault.setClaimer(_newClaimer);

    assertEq(vault.claimer(), address(_newClaimer));
  }

  function testSetClaimerOnlyOwner() public {
    address _caller = address(0xc6781d43c1499311291c8E5d3ab79613dc9e6d98);
    address _newClaimer = makeAddr("newClaimer");

    vm.startPrank(_caller);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setClaimer(_newClaimer);

    vm.stopPrank();
  }

  function testSetClaimerZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));
    vault.setClaimer(address(0));
  }

  /* ============ setLiquidationPair ============ */
  function testSetLiquidationPair() public {
    vm.expectEmit();
    emit LiquidationPairSet(address(vault), address(liquidationPair));

    vault.setLiquidationPair(address(liquidationPair));

    assertEq(vault.liquidationPair(), address(liquidationPair));
  }

  function testSetLiquidationPairNotZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(PrizeVault.LPZeroAddress.selector));
    vault.setLiquidationPair(address(0));
  }

  function testSetLiquidationPairOnlyOwner() public {
    address _newLiquidationPair = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vm.startPrank(alice);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setLiquidationPair(_newLiquidationPair);

    vm.stopPrank();
  }

  /* ============ isLiquidationPair ============ */
  function testIsLiquidationPair() public {
    address _newLiquidationPair = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vault.setLiquidationPair(address(liquidationPair));
    assertEq(vault.isLiquidationPair(address(underlyingAsset), address(_newLiquidationPair)), false);
    assertEq(vault.isLiquidationPair(address(underlyingAsset), address(liquidationPair)), true);
    assertEq(vault.isLiquidationPair(address(1), address(liquidationPair)), false);

    vault.setLiquidationPair(_newLiquidationPair);
    assertEq(vault.isLiquidationPair(address(underlyingAsset), address(_newLiquidationPair)), true);
    assertEq(vault.isLiquidationPair(address(underlyingAsset), address(liquidationPair)), false);
    assertEq(vault.isLiquidationPair(address(1), address(_newLiquidationPair)), false);
  }

  /* ============ testSetYieldFeePercentage ============ */
  function testSetYieldFeePercentage() public {
    vm.expectEmit();
    emit YieldFeePercentageSet(YIELD_FEE_PERCENTAGE);

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
  }

  function testSetYieldFeePercentageGT1e9() public {
    vm.expectRevert(
      abi.encodeWithSelector(PrizeVault.YieldFeePercentageGtPrecision.selector, 2e9, 1e9)
    );
    vault.setYieldFeePercentage(2e9);
  }

  function testSetYieldFeePercentageOnlyOwner() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setYieldFeePercentage(1e9);

    vm.stopPrank();
  }

  /* ============ setYieldFeeRecipient ============ */
  function testSetYieldFeeRecipient() public {
    vm.expectEmit(true, true, true, true);
    emit YieldFeeRecipientSet(alice);

    vault.setYieldFeeRecipient(alice);
    assertEq(vault.yieldFeeRecipient(), alice);
  }

  function testSetYieldFeeRecipientOnlyOwner() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setYieldFeeRecipient(bob);

    vm.stopPrank();
  }

  function claimPrize(
    uint8 tier,
    address winner,
    uint32 prizeIndex,
    uint96 fee,
    address feeRecipient
  ) public returns (uint256) {
    return vault.claimPrize(winner, tier, prizeIndex, fee, feeRecipient);
  }

  /* ============ mocks ============ */
  function mockPrizePoolClaimPrize(
    uint8 _tier,
    address _winner,
    uint32 _prizeIndex,
    uint96 _fee,
    address _feeRecipient
  ) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(
        PrizePool.claimPrize.selector,
        _winner,
        _tier,
        _prizeIndex,
        _winner,
        _fee,
        _feeRecipient
      ),
      abi.encode(100)
    );
  }

  function mockPrizePoolClaimPrize(
    uint8 _tier,
    address _winner,
    uint32 _prizeIndex,
    address _recipient,
    uint96 _fee,
    address _feeRecipient
  ) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(
        PrizePool.claimPrize.selector,
        _winner,
        _tier,
        _prizeIndex,
        _recipient,
        _fee,
        _feeRecipient
      ),
      abi.encode(100)
    );
  }
}

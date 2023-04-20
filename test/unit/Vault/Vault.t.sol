// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { UnitBaseSetup, Claimer, LiquidationPair, PrizePool, TwabController, Vault, ERC20, IERC20, IERC4626 } from "test/utils/UnitBaseSetup.t.sol";

contract VaultTest is UnitBaseSetup {
  /* ============ Events ============ */

  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    PrizePool indexed prizePool,
    Claimer claimer,
    address yieldFeeRecipient,
    uint256 yieldFeePercentage,
    address owner
  );

  event AutoClaimDisabled(address user, bool status);

  event ClaimerSet(Claimer previousClaimer, Claimer newClaimer);

  event LiquidationPairSet(LiquidationPair newLiquidationPair);

  event YieldFeeRecipientSet(address previousYieldFeeRecipient, address newYieldFeeRecipient);

  event YieldFeePercentageSet(uint256 previousYieldFeePercentage, uint256 newYieldFeePercentage);

  /* ============ Constructor ============ */

  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit NewVault(
      IERC20(address(underlyingAsset)),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );

    Vault testVault = new Vault(
      IERC20(address(underlyingAsset)),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );

    assertEq(testVault.asset(), address(underlyingAsset));
    assertEq(testVault.name(), vaultName);
    assertEq(testVault.symbol(), vaultSymbol);
    assertEq(testVault.decimals(), ERC20(address(underlyingAsset)).decimals());
    assertEq(testVault.twabController(), address(twabController));
    assertEq(testVault.yieldVault(), address(yieldVault));
    assertEq(testVault.prizePool(), address(prizePool));
    assertEq(testVault.claimer(), address(claimer));
    assertEq(testVault.owner(), address(this));
  }

  function testConstructorTwabControllerZero() external {
    vm.expectRevert(bytes("Vault/twabCtrlr-not-zero-address"));

    new Vault(
      IERC20(address(underlyingAsset)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      TwabController(address(0)),
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("Vault/YV-not-zero-address"));

    new Vault(
      IERC20(address(underlyingAsset)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      IERC4626(address(0)),
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testConstructorPrizePoolZero() external {
    vm.expectRevert(bytes("Vault/PP-not-zero-address"));

    new Vault(
      IERC20(address(underlyingAsset)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      PrizePool(address(0)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testConstructorOwnerZero() external {
    vm.expectRevert(bytes("Vault/owner-not-zero-address"));

    new Vault(
      IERC20(address(underlyingAsset)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(0)
    );
  }

  /* ============ External functions ============ */

  /* ============ targetOf ============ */
  function testTargetOf() public {
    _setLiquidationPair();

    address target = vault.targetOf(address(prizeToken));
    assertEq(target, address(prizePool));
  }

  function testTargetOfFail() public {
    _setLiquidationPair();

    vm.expectRevert(bytes("Vault/target-token-unsupported"));
    vault.targetOf(address(underlyingAsset));
  }

  /* ============ Claimer ============ */
  /* ============ disableAutoClaim ============ */
  function testDisableAutoClaimFalse() public {
    bool disable = false;

    vm.expectEmit(true, true, true, true);
    emit AutoClaimDisabled(address(this), disable);

    bool status = vault.disableAutoClaim(disable);

    assertEq(status, disable);
    assertEq(vault.autoClaimDisabled(address(this)), disable);
  }

  function testDisableAutoClaimTrue() public {
    bool disable = true;

    vm.expectEmit(true, true, true, true);
    emit AutoClaimDisabled(address(this), disable);

    bool status = vault.disableAutoClaim(disable);

    assertEq(status, disable);
    assertEq(vault.autoClaimDisabled(address(this)), disable);
  }

  /* ============ claimPrize ============ */
  function testClaimPrize() public {
    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(alice, uint8(1), alice, 1e18, address(claimer));
    vault.claimPrize(alice, uint8(1), alice, 1e18, address(claimer));

    vm.stopPrank();
  }

  function testClaimPrizeClaimerNotSet() public {
    vault.setClaimer(Claimer(address(0)));

    address _randomUser = address(0xFf107770b6a31261836307218997C66c34681B5A);

    vm.startPrank(_randomUser);

    mockPrizePoolClaimPrize(alice, uint8(1), alice, 0, address(0));
    vault.claimPrize(alice, uint8(1), alice, 0, address(0));

    vm.stopPrank();
  }

  function testClaimPrizeCallerNotClaimer() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes("Vault/caller-not-claimer"));
    vault.claimPrize(alice, uint8(1), alice, 0, address(0));

    vm.stopPrank();
  }

  function testClaimPrizeAutoClaimDisabled() public {
    vm.startPrank(alice);

    vault.disableAutoClaim(true);

    vm.stopPrank();

    vm.startPrank(address(claimer));

    vm.expectRevert(bytes("Vault/auto-claim-disabled"));
    vault.claimPrize(alice, uint8(1), alice, 1e18, address(this));

    vm.stopPrank();

    vm.startPrank(alice);

    mockPrizePoolClaimPrize(alice, uint8(1), alice, 0, address(0));
    vault.claimPrize(alice, uint8(1), alice, 0, address(0));

    vm.stopPrank();
  }

  /* ============ Getters ============ */
  function testGetTwabController() external {
    assertEq(vault.twabController(), address(twabController));
  }

  function testGetYieldVault() external {
    assertEq(vault.yieldVault(), address(yieldVault));
  }

  function testGetLiquidationPair() external {
    vault.setLiquidationPair(LiquidationPair(address(liquidationPair)));
    assertEq(vault.liquidationPair(), address(liquidationPair));
  }

  function testGetPrizePool() external {
    assertEq(vault.prizePool(), address(prizePool));
  }

  function testGetClaimer() external {
    assertEq(vault.claimer(), address(claimer));
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
    Claimer _newClaimer = Claimer(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vm.expectEmit(true, true, true, true);
    emit ClaimerSet(claimer, _newClaimer);

    address _newClaimerAddress = vault.setClaimer(_newClaimer);

    assertEq(_newClaimerAddress, address(_newClaimer));
    assertEq(vault.claimer(), address(_newClaimer));
  }

  function testSetClaimerOnlyOwner() public {
    address _caller = address(0xc6781d43c1499311291c8E5d3ab79613dc9e6d98);
    Claimer _newClaimer = Claimer(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vm.startPrank(_caller);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setClaimer(_newClaimer);

    vm.stopPrank();
  }

  /* ============ setLiquidationPair ============ */
  function testSetLiquidationPair() public {
    vm.expectEmit(true, true, true, true);
    emit LiquidationPairSet(LiquidationPair(address(liquidationPair)));

    address _newLiquidationPairAddress = _setLiquidationPair();

    assertEq(_newLiquidationPairAddress, address(liquidationPair));
    assertEq(vault.liquidationPair(), address(liquidationPair));
    assertEq(
      underlyingAsset.allowance(address(vault), _newLiquidationPairAddress),
      type(uint256).max
    );
  }

  function testSetLiquidationPairUpdate() public {
    vault.setLiquidationPair(LiquidationPair(address(liquidationPair)));

    assertEq(
      underlyingAsset.allowance(address(vault), address(liquidationPair)),
      type(uint256).max
    );

    LiquidationPair _newLiquidationPair = LiquidationPair(
      0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820
    );

    vault.setLiquidationPair(_newLiquidationPair);

    assertEq(underlyingAsset.allowance(address(vault), address(liquidationPair)), 0);
    assertEq(
      underlyingAsset.allowance(address(vault), address(_newLiquidationPair)),
      type(uint256).max
    );
  }

  function testSetLiquidationPairNotZeroAddress() public {
    vm.expectRevert(bytes("Vault/LP-not-zero-address"));
    vault.setLiquidationPair(LiquidationPair(address(0)));
  }

  function testSetLiquidationPairOnlyOwner() public {
    LiquidationPair _newLiquidationPair = LiquidationPair(
      0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820
    );

    vm.startPrank(alice);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setLiquidationPair(_newLiquidationPair);

    vm.stopPrank();
  }

  /* ============ testSetYieldFeePercentage ============ */
  function testSetYieldFeePercentage() public {
    vm.expectEmit();
    emit YieldFeePercentageSet(0, YIELD_FEE_PERCENTAGE);

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
  }

  function testSetYieldFeePercentageGT1e9() public {
    vm.expectRevert(bytes("Vault/yieldFeePercentage-gt-1e9"));
    vault.setYieldFeePercentage(1e10);
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
    emit YieldFeeRecipientSet(address(this), alice);

    vault.setYieldFeeRecipient(alice);
    assertEq(vault.yieldFeeRecipient(), alice);
  }

  function testSetYieldFeeRecipientOnlyOwner() public {
    vm.startPrank(alice);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setYieldFeeRecipient(bob);

    vm.stopPrank();
  }

  /* ============ mocks ============ */
  function mockPrizePoolClaimPrize(
    address _winner,
    uint8 _tier,
    address _to,
    uint96 _fee,
    address _feeRecipient
  ) public {
    vm.mockCall(
      address(prizePool),
      abi.encodeWithSelector(
        PrizePool.claimPrize.selector,
        _winner,
        _tier,
        _to,
        _fee,
        _feeRecipient
      ),
      abi.encode(100)
    );
  }
}

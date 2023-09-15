// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import { UnitBaseSetup, ILiquidationPair, PrizePool, TwabController, Vault, ERC20, IERC20, IERC4626 } from "../../utils/UnitBaseSetup.t.sol";
import { IVaultHooks, VaultHooks } from "../../../src/interfaces/IVaultHooks.sol";

import "../../../src/Vault.sol";

contract VaultTest is UnitBaseSetup {
  /* ============ Events ============ */

  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    PrizePool indexed prizePool,
    address claimer,
    address yieldFeeRecipient,
    uint256 yieldFeePercentage,
    address owner
  );

  event ClaimerSet(address indexed claimer);

  event LiquidationPairSet(ILiquidationPair indexed newLiquidationPair);

  event YieldFeeRecipientSet(address indexed yieldFeeRecipient);

  event YieldFeePercentageSet(uint256 yieldFeePercentage);

  event SetHooks(address indexed account, VaultHooks indexed hooks);

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
    assertEq(testVault.twabController(), address(twabController));
    assertEq(testVault.yieldVault(), address(yieldVault));
    assertEq(testVault.prizePool(), address(prizePool));
    assertEq(testVault.claimer(), address(claimer));
    assertEq(testVault.owner(), address(this));
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(abi.encodeWithSelector(YieldVaultZeroAddress.selector));

    new Vault(
      IERC20(address(underlyingAsset)),
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

  function testConstructorPrizePoolZero() external {
    vm.expectRevert(abi.encodeWithSelector(PrizePoolZeroAddress.selector));

    new Vault(
      IERC20(address(underlyingAsset)),
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
    vm.expectRevert(abi.encodeWithSelector(OwnerZeroAddress.selector));

    new Vault(
      IERC20(address(underlyingAsset)),
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

  function testConstructorUnderlyingAssetMismatch() external {
    vm.mockCall(
      address(yieldVault),
      abi.encodeWithSelector(IERC4626.asset.selector),
      abi.encode(address(0))
    );

    vm.expectRevert(
      abi.encodeWithSelector(UnderlyingAssetMismatch.selector, address(underlyingAsset), address(0))
    );

    new Vault(
      IERC20(address(underlyingAsset)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      yieldVault,
      PrizePool(address(prizePool)),
      claimer,
      address(this),
      YIELD_FEE_PERCENTAGE,
      address(this)
    );
  }

  function testConstructorClaimerZero() external {
    vm.expectRevert(abi.encodeWithSelector(ClaimerZeroAddress.selector));

    new Vault(
      IERC20(address(underlyingAsset)),
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

  /* ============ Claimer ============ */

  /* ============ isClaimer ============ */
  function testIsClaimer() public {
    assertEq(vault.isClaimer(address(0)), false);
    assertEq(vault.isClaimer(address(this)), false);
    assertEq(vault.isClaimer(address(claimer)), true);
  }

  /* ============ claimPrize ============ */
  function testClaimPrize() public {
    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(uint8(1), alice, 0, 1e18, address(claimer));
    claimPrize(uint8(1), alice, 0, 1e18, address(claimer));

    vm.stopPrank();
  }

  function testClaimPrize_beforeHook() public {
    vm.startPrank(alice);
    VaultHooks memory hooks = VaultHooks({
      useBeforeClaimPrize: true,
      useAfterClaimPrize: false,
      implementation: IVaultHooks(makeAddr("hooks"))
    });
    vault.setHooks(hooks);
    vm.stopPrank();

    vm.mockCall(
      address(hooks.implementation),
      abi.encodeWithSelector(IVaultHooks.beforeClaimPrize.selector, alice, 1, 0),
      abi.encode(bob)
    );

    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(uint8(1), alice, 0, bob, 1e18, address(claimer));
    claimPrize(uint8(1), alice, 0, 1e18, address(claimer));

    vm.stopPrank();
  }

  function testClaimPrize_afterHook() public {
    vm.startPrank(alice);
    VaultHooks memory hooks = VaultHooks({
      useBeforeClaimPrize: true,
      useAfterClaimPrize: true,
      implementation: IVaultHooks(makeAddr("hooks"))
    });
    vault.setHooks(hooks);
    vm.stopPrank();

    vm.mockCall(
      address(hooks.implementation),
      abi.encodeWithSelector(IVaultHooks.beforeClaimPrize.selector, alice, 1, 0),
      abi.encode(bob)
    );
    vm.mockCall(
      address(hooks.implementation),
      abi.encodeWithSelector(IVaultHooks.afterClaimPrize.selector, alice, 1, 0, 78, bob),
      abi.encode(true)
    );

    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(uint8(1), alice, 0, bob, 22, address(claimer));
    claimPrize(uint8(1), alice, 0, 22, address(claimer));

    vm.stopPrank();
  }

  function testClaimPrizesClaimerNotSet() public {
    address _randomUser = address(0xFf107770b6a31261836307218997C66c34681B5A);

    vm.startPrank(_randomUser);

    mockPrizePoolClaimPrize(uint8(1), alice, 0, 0, address(0));
    vm.expectRevert(
      abi.encodeWithSelector(CallerNotClaimer.selector, _randomUser, address(claimer))
    );

    claimPrize(uint8(1), alice, 0, 0, address(0));

    vm.stopPrank();
  }

  function testClaimPrizeCallerNotClaimer() public {
    vm.startPrank(alice);

    vm.expectRevert(abi.encodeWithSelector(CallerNotClaimer.selector, alice, claimer));
    vault.claimPrize(alice, uint8(1), uint32(0), uint96(0), address(0));

    vm.stopPrank();
  }

  function testClaimPrizeBeforeHookRecipientZeroAddress() public {
    vm.startPrank(alice);

    VaultHooks memory hooks = VaultHooks({
      useBeforeClaimPrize: true,
      useAfterClaimPrize: false,
      implementation: IVaultHooks(makeAddr("hooks"))
    });

    vault.setHooks(hooks);

    vm.stopPrank();

    vm.mockCall(
      address(hooks.implementation),
      abi.encodeWithSelector(IVaultHooks.beforeClaimPrize.selector, alice, 1, 0),
      abi.encode(address(0))
    );

    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(uint8(1), alice, 0, bob, 1e18, address(claimer));

    vm.expectRevert(abi.encodeWithSelector(ClaimRecipientZeroAddress.selector));
    claimPrize(uint8(1), alice, 0, 1e18, address(claimer));

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
    vault.setLiquidationPair(ILiquidationPair(address(liquidationPair)));
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
    address _newClaimer = makeAddr("claimer");

    vm.expectEmit(true, true, true, true);
    emit ClaimerSet(_newClaimer);

    address _newClaimerAddress = vault.setClaimer(_newClaimer);

    assertEq(_newClaimerAddress, address(_newClaimer));
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
    vm.expectRevert(abi.encodeWithSelector(ClaimerZeroAddress.selector));
    vault.setClaimer(address(0));
  }

  /* ============ setLiquidationPair ============ */
  function testSetLiquidationPair() public {
    vm.expectEmit();
    emit LiquidationPairSet(ILiquidationPair(address(liquidationPair)));

    address _newLiquidationPairAddress = _setLiquidationPair();

    assertEq(_newLiquidationPairAddress, address(liquidationPair));
    assertEq(vault.liquidationPair(), address(liquidationPair));
  }

  function testSetLiquidationPairNotZeroAddress() public {
    vm.expectRevert(abi.encodeWithSelector(LPZeroAddress.selector));
    vault.setLiquidationPair(ILiquidationPair(address(0)));
  }

  function testSetLiquidationPairOnlyOwner() public {
    ILiquidationPair _newLiquidationPair = ILiquidationPair(
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
    emit YieldFeePercentageSet(YIELD_FEE_PERCENTAGE);

    vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
    assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
  }

  function testSetYieldFeePercentageGT1e9() public {
    vm.expectRevert(abi.encodeWithSelector(YieldFeePercentageGtePrecision.selector, 2e9, 1e9));
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

  function testSetHooks() public {
    vm.startPrank(bob);

    VaultHooks memory hooks = VaultHooks({
      useBeforeClaimPrize: true,
      useAfterClaimPrize: true,
      implementation: IVaultHooks(makeAddr("hooks"))
    });

    vm.expectEmit(true, true, true, true);
    emit SetHooks(bob, hooks);
    vault.setHooks(hooks);

    VaultHooks memory result = vault.getHooks(bob);
    assertEq(result.useBeforeClaimPrize, hooks.useBeforeClaimPrize);
    assertEq(result.useAfterClaimPrize, hooks.useAfterClaimPrize);
    assertEq(address(result.implementation), address(hooks.implementation));

    vm.stopPrank();
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

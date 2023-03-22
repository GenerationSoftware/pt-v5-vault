// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock, IERC20Metadata } from "openzeppelin/mocks/ERC20Mock.sol";

import { ILiquidationSource } from "v5-liquidator-interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "v5-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "v5-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "v5-liquidator/LiquidationRouter.sol";
import { UFixed32x9 } from "v5-liquidator-libraries/FixedMathLib.sol";

import { PrizePool, SD59x18 } from "v5-prize-pool/PrizePool.sol";
import { ud2x18, sd1x18 } from "v5-prize-pool-test/PrizePool.t.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";
import { Claimer } from "v5-vrgda-claimer/Claimer.sol";

import { Vault } from "src/Vault.sol";

import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract VaultTest is Test {
  /* ============ Events ============ */
  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    PrizePool indexed prizePool,
    Claimer claimer,
    address owner
  );

  event AutoClaimDisabled(address user, bool status);

  event ClaimerSet(Claimer previousClaimer, Claimer newClaimer);

  event LiquidationPairSet(
    LiquidationPair previousLiquidationPair,
    LiquidationPair newLiquidationPair
  );

  event Sponsor(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);

  /* ============ Variables ============ */
  address user = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

  Vault public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

  IERC4626 public yieldVault;
  ERC20Mock public underlyingToken;
  ERC20Mock public prizeToken;

  LiquidationRouter public liquidationRouter;
  LiquidationPair public liquidationPair;
  address public liquidationPairTarget = 0xcbE704e38ddB2E6A8bA9f4d335f2637132C20113;

  Claimer public claimer;
  PrizePool public prizePool;

  uint256 public winningRandomNumber = 123456;
  uint32 public drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ Setup ============ */

  function setUp() public {
    underlyingToken = new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0);
    prizeToken = new ERC20Mock("PoolTogether", "POOL", address(this), 0);

    twabController = new TwabController();

    prizePool = new PrizePool(
      prizeToken,
      twabController,
      uint32(365), // 52 weeks = 1 year
      drawPeriodSeconds, // drawPeriodSeconds
      uint64(block.timestamp), // drawStartedAt
      uint8(2), // minimum number of tiers
      100e18,
      10e18,
      10e18,
      ud2x18(0.9e18), // claim threshold of 90%
      sd1x18(0.9e18) // alpha
    );

    claimer = new Claimer(prizePool, ud2x18(1.1e18), 0.0001e18);

    yieldVault = new YieldVault(
      underlyingToken,
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    vault = new Vault(
      underlyingToken,
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this)
    );

    liquidationPair = new LiquidationPair(
      ILiquidationSource(vault),
      address(prizeToken),
      address(vault),
      UFixed32x9.wrap(0.3e9),
      UFixed32x9.wrap(0.02e9),
      100,
      50
    );

    liquidationRouter = new LiquidationRouter(new LiquidationPairFactory());
  }

  /* ============ Constructor ============ */

  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit NewVault(
      IERC20(address(underlyingToken)),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this)
    );

    Vault testVault = new Vault(
      IERC20(address(underlyingToken)),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(this)
    );

    assertEq(testVault.asset(), address(underlyingToken));
    assertEq(testVault.name(), vaultName);
    assertEq(testVault.symbol(), vaultSymbol);
    assertEq(testVault.decimals(), ERC20(address(underlyingToken)).decimals());
    assertEq(testVault.twabController(), address(twabController));
    assertEq(testVault.yieldVault(), address(yieldVault));
    assertEq(testVault.prizePool(), address(prizePool));
    assertEq(testVault.claimer(), address(claimer));
    assertEq(testVault.owner(), address(this));
  }

  function testConstructorTwabControllerZero() external {
    vm.expectRevert(bytes("Vault/twabCtrlr-not-zero-address"));

    new Vault(
      IERC20(address(underlyingToken)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      TwabController(address(0)),
      yieldVault,
      prizePool,
      claimer,
      address(this)
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("Vault/YV-not-zero-address"));

    new Vault(
      IERC20(address(underlyingToken)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      IERC4626(address(0)),
      prizePool,
      claimer,
      address(this)
    );
  }

  function testConstructorPrizePoolZero() external {
    vm.expectRevert(bytes("Vault/PP-not-zero-address"));

    new Vault(
      IERC20(address(underlyingToken)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      PrizePool(address(0)),
      claimer,
      address(this)
    );
  }

  function testConstructorOwnerZero() external {
    vm.expectRevert(bytes("Vault/owner-not-zero-address"));

    new Vault(
      IERC20(address(underlyingToken)),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      prizePool,
      claimer,
      address(0)
    );
  }

  /* ============ External functions ============ */

  /* ============ Sponsor ============ */
  function testSponsor() public {
    vm.startPrank(address(vault));

    uint256 _amount = 1000e18;
    underlyingToken.mint(address(this), _amount);

    changePrank(address(this));

    vm.expectEmit(true, true, true, true);
    emit Sponsor(address(this), address(this), _amount, _amount);

    underlyingToken.approve(address(vault), _amount);
    vault.sponsor(_amount, address(this));

    assertEq(IERC20(vault).balanceOf(address(this)), _amount);
    assertEq(vault.balanceOf(address(this)), _amount);

    assertEq(twabController.balanceOf(address(vault), address(this)), _amount);
    assertEq(twabController.delegateBalanceOf(address(vault), address(this)), 0);

    address _sponsorshipAddress = twabController.SPONSORSHIP_ADDRESS();

    assertEq(vault.balanceOf(_sponsorshipAddress), 0);
    assertEq(twabController.delegateBalanceOf(address(vault), _sponsorshipAddress), 0);

    assertEq(underlyingToken.balanceOf(address(yieldVault)), _amount);
    assertEq(IERC20(yieldVault).balanceOf(address(vault)), _amount);
    assertEq(yieldVault.balanceOf(address(vault)), _amount);

    vm.stopPrank();
  }

  function testLiquidateCallerNotLP() public {
    vault.setLiquidationPair(liquidationPair);

    vm.expectRevert(bytes("Vault/caller-not-LP"));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), 0);
  }

  function testLiquidateTokenInNotPrizeToken() public {
    vault.setLiquidationPair(liquidationPair);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/tokenIn-not-prizeToken"));
    vault.liquidate(address(this), address(0), 0, address(vault), 0);

    vm.stopPrank();
  }

  function testLiquidateTokenOutNotVaultShare() public {
    vault.setLiquidationPair(liquidationPair);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/tokenOut-not-vaultShare"));
    vault.liquidate(address(this), address(prizeToken), 0, address(0), 0);

    vm.stopPrank();
  }

  function testLiquidateAmountGTAvailableYield() public {
    vault.setLiquidationPair(liquidationPair);

    vm.startPrank(address(liquidationPair));

    vm.expectRevert(bytes("Vault/amount-gt-available-yield"));
    vault.liquidate(address(this), address(prizeToken), 0, address(vault), type(uint256).max);

    vm.stopPrank();
  }

  /* ============ targetOf ============ */
  function testTargetOf() public {
    vault.setLiquidationPair(liquidationPair);

    address target = vault.targetOf(address(prizeToken));
    assertEq(target, address(prizePool));
  }

  function testTargetOfFail() public {
    vault.setLiquidationPair(liquidationPair);

    vm.expectRevert(bytes("Vault/target-token-unsupported"));
    vault.targetOf(address(underlyingToken));
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

  /* ============ claimPrize ============ */
  function testClaimPrize() public {
    vm.startPrank(address(claimer));

    mockPrizePoolClaimPrize(user, uint8(1), user, 1e18, address(claimer));
    vault.claimPrize(user, uint8(1), user, 1e18, address(claimer));

    vm.stopPrank();
  }

  function testClaimPrizeClaimerNotSet() public {
    vault.setClaimer(Claimer(address(0)));

    address _randomUser = address(0xFf107770b6a31261836307218997C66c34681B5A);

    vm.startPrank(_randomUser);

    mockPrizePoolClaimPrize(user, uint8(1), user, 0, address(0));
    vault.claimPrize(user, uint8(1), user, 0, address(0));

    vm.stopPrank();
  }

  function testClaimPrizeCallerNotClaimer() public {
    vm.startPrank(user);

    vm.expectRevert(bytes("Vault/caller-not-claimer"));
    vault.claimPrize(user, uint8(1), user, 0, address(0));

    vm.stopPrank();
  }

  function testClaimPrizeAutoClaimDisabled() public {
    vm.startPrank(user);

    vault.disableAutoClaim(true);

    vm.stopPrank();

    vm.startPrank(address(claimer));

    vm.expectRevert(bytes("Vault/auto-claim-disabled"));
    vault.claimPrize(user, uint8(1), user, 1e18, address(this));

    vm.stopPrank();

    vm.startPrank(user);

    mockPrizePoolClaimPrize(user, uint8(1), user, 0, address(0));
    vault.claimPrize(user, uint8(1), user, 0, address(0));

    vm.stopPrank();
  }

  /* ============ setLiquidationPair ============ */
  function testSetLiquidationPair() public {
    vm.expectEmit(true, true, true, true);
    emit LiquidationPairSet(LiquidationPair(address(0)), liquidationPair);

    address _newLiquidationPairAddress = vault.setLiquidationPair(liquidationPair);

    assertEq(_newLiquidationPairAddress, address(liquidationPair));
    assertEq(vault.liquidationPair(), address(liquidationPair));
    assertEq(
      underlyingToken.allowance(address(vault), _newLiquidationPairAddress),
      type(uint256).max
    );
  }

  function testSetLiquidationPairUpdate() public {
    vault.setLiquidationPair(liquidationPair);

    assertEq(
      underlyingToken.allowance(address(vault), address(liquidationPair)),
      type(uint256).max
    );

    LiquidationPair _newLiquidationPair = LiquidationPair(
      0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820
    );

    vault.setLiquidationPair(_newLiquidationPair);

    assertEq(underlyingToken.allowance(address(vault), address(liquidationPair)), 0);
    assertEq(
      underlyingToken.allowance(address(vault), address(_newLiquidationPair)),
      type(uint256).max
    );
  }

  function testSetLiquidationPairNotZeroAddress() public {
    vm.expectRevert(bytes("Vault/LP-not-zero-address"));
    vault.setLiquidationPair(LiquidationPair(address(0)));
  }

  function testSetLiquidationPairOnlyOwner() public {
    address _caller = address(0xc6781d43c1499311291c8E5d3ab79613dc9e6d98);
    LiquidationPair _newLiquidationPair = LiquidationPair(
      0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820
    );

    vm.startPrank(_caller);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setLiquidationPair(_newLiquidationPair);

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

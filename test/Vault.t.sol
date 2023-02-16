// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/Test.sol";
import { ERC4626Test, IMockERC20 } from "erc4626-tests/ERC4626.test.sol";
import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock, IERC20Metadata } from "openzeppelin/mocks/ERC20Mock.sol";

import { ILiquidationSource } from "v5-liquidator/src/interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "v5-liquidator/src/LiquidationPair.sol";
import { UFixed32x9 } from "v5-liquidator/src/libraries/FixedMathLib.sol";

import { PrizePool, SD59x18 } from "v5-prize-pool/src/PrizePool.sol";
import { ud2x18, sd1x18 } from "v5-prize-pool/test/PrizePool.t.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";

import { Vault } from "src/Vault.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract VaultTest is ERC4626Test {
  /* ============ Events ============ */

  event NewVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    LiquidationPair indexed liquidationPair,
    PrizePool prizePool,
    address claimer,
    address owner
  );

  event AutoClaimDisabled(address user, bool status);

  event ClaimerSet(address previousClaimer, address newClaimer);

  /* ============ Variables ============ */

  Vault public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

  IERC4626 public yieldVault;
  ERC20Mock public underlyingToken;
  ERC20Mock public prizeToken;

  LiquidationPair public liquidationPair;
  address public liquidationPairTarget = 0xcbE704e38ddB2E6A8bA9f4d335f2637132C20113;

  PrizePool public prizePool;

  uint256 winningRandomNumber = 123456;
  uint32 drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ Setup ============ */

  function setUp() public override {
    underlyingToken = new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0);
    _underlying_ = address(underlyingToken);

    prizeToken = new ERC20Mock("PoolTogether", "POOL", address(this), 0);

    liquidationPair = new LiquidationPair(
      ILiquidationSource(vault),
      address(prizeToken),
      address(vault),
      UFixed32x9.wrap(0.3e9),
      UFixed32x9.wrap(0.02e9),
      100,
      50
    );

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
      liquidationPair,
      prizePool,
      address(this), // TODO: replace with claimer contract address
      address(this)
    );

    _vault_ = address(vault);

    _delta_ = 0;
    _vaultMayBeEmpty = false;
    _unlimitedAmount = true;
  }

  /* ============ Constructor ============ */

  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit NewVault(
      IERC20(_underlying_),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      liquidationPair,
      prizePool,
      address(this),
      address(this)
    );

    Vault testVault = new Vault(
      IERC20(_underlying_),
      vaultName,
      vaultSymbol,
      twabController,
      yieldVault,
      liquidationPair,
      prizePool,
      address(this),
      address(this)
    );

    assertEq(testVault.asset(), _underlying_);
    assertEq(testVault.name(), vaultName);
    assertEq(testVault.symbol(), vaultSymbol);
    assertEq(testVault.decimals(), ERC20(_underlying_).decimals());
    assertEq(testVault.twabController(), address(twabController));
    assertEq(testVault.yieldVault(), address(yieldVault));
    assertEq(testVault.liquidationPair(), address(liquidationPair));
    assertEq(testVault.prizePool(), address(prizePool));
    assertEq(testVault.claimer(), address(this));
    assertEq(testVault.owner(), address(this));
  }

  function testConstructorTwabControllerZero() external {
    vm.expectRevert(bytes("Vault/twabCtrlr-not-zero-address"));

    new Vault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      TwabController(address(0)),
      yieldVault,
      liquidationPair,
      prizePool,
      address(this),
      address(this)
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("Vault/YV-not-zero-address"));

    new Vault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      IERC4626(address(0)),
      liquidationPair,
      prizePool,
      address(this),
      address(this)
    );
  }

  function testConstructorLiquidationPairZero() external {
    vm.expectRevert(bytes("Vault/LP-not-zero-address"));

    new Vault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      LiquidationPair(address(0)),
      prizePool,
      address(this),
      address(this)
    );
  }

  function testConstructorPrizePoolZero() external {
    vm.expectRevert(bytes("Vault/PP-not-zero-address"));

    new Vault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      liquidationPair,
      PrizePool(address(0)),
      address(this),
      address(this)
    );
  }

  function testConstructorOwnerZero() external {
    vm.expectRevert(bytes("Vault/owner-not-zero-address"));

    new Vault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      liquidationPair,
      prizePool,
      address(this),
      address(0)
    );
  }

  /* ============ External functions ============ */

  /* ============ Deposit ============ */
  function propDeposit(address caller, address receiver, uint256 assets) public {
    uint256 oldCallerAsset = IERC20(_underlying_).balanceOf(caller);
    uint256 oldVaultAsset = IERC20(_underlying_).balanceOf(_vault_);
    uint256 oldReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint256 oldAllowance = IERC20(_underlying_).allowance(caller, _vault_);

    vm.prank(caller);
    uint256 shares = vault_deposit(assets, receiver);

    uint256 newCallerAsset = IERC20(_underlying_).balanceOf(caller);
    uint256 newVaultAsset = IERC20(_underlying_).balanceOf(_vault_);
    uint256 newReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint256 newAllowance = IERC20(_underlying_).allowance(caller, _vault_);

    // There are assets in the vault
    if (oldVaultAsset != 0) {
      // We need to transfer some assets to the vault to fulfill deposit
      if (assets > oldVaultAsset) {
        uint256 assetsDeposit = assets - oldVaultAsset;

        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assetsDeposit, _delta_, "asset");
        assertApproxEqAbs(
          newVaultAsset,
          oldVaultAsset - (assets - assetsDeposit),
          _delta_,
          "vault asset"
        );
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

        if (oldAllowance != type(uint).max) {
          assertApproxEqAbs(newAllowance, oldAllowance - assetsDeposit, _delta_, "allowance");
        }
      } else {
        // We don't need to transfer assets to the vault to fulfill deposit
        assertApproxEqAbs(newCallerAsset, oldCallerAsset, _delta_, "asset");
        assertApproxEqAbs(newVaultAsset, oldVaultAsset - assets, _delta_, "vault asset");
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

        if (oldAllowance != type(uint).max) {
          assertApproxEqAbs(newAllowance, oldAllowance, _delta_, "allowance");
        }
      }
    } else {
      // No assets in the vault, we need to transfer assets to the vault
      assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, _delta_, "asset");
      assertApproxEqAbs(newVaultAsset, oldVaultAsset, _delta_, "vault asset");
      assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

      if (oldAllowance != type(uint).max) {
        assertApproxEqAbs(newAllowance, oldAllowance - assets, _delta_, "allowance");
      }
    }
  }

  function test_deposit(Init memory init, uint assets, uint allowance) public virtual override {
    setUpVault(init);
    address caller = init.user[0];
    address receiver = init.user[1];
    assets = bound(assets, 0, _max_deposit(caller));
    _approve(_underlying_, caller, _vault_, allowance);
    propDeposit(caller, receiver, assets);
  }

  /* ============ Mint ============ */
  function propMint(address caller, address receiver, uint shares) public {
    uint oldCallerAsset = IERC20(_underlying_).balanceOf(caller);
    uint256 oldVaultAsset = IERC20(_underlying_).balanceOf(_vault_);
    uint oldReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint oldAllowance = IERC20(_underlying_).allowance(caller, _vault_);

    vm.prank(caller);
    uint assets = vault_mint(shares, receiver);

    uint newCallerAsset = IERC20(_underlying_).balanceOf(caller);
    uint256 newVaultAsset = IERC20(_underlying_).balanceOf(_vault_);
    uint newReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint newAllowance = IERC20(_underlying_).allowance(caller, _vault_);

    // There are assets in the vault
    if (oldVaultAsset != 0) {
      // We need to transfer some assets to the vault to fulfill mint
      if (assets > oldVaultAsset) {
        uint256 assetsDeposit = assets - oldVaultAsset;

        assertApproxEqAbs(newCallerAsset, oldCallerAsset - assetsDeposit, _delta_, "asset");
        assertApproxEqAbs(
          newVaultAsset,
          oldVaultAsset - (assets - assetsDeposit),
          _delta_,
          "vault asset"
        );
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

        if (oldAllowance != type(uint).max) {
          assertApproxEqAbs(newAllowance, oldAllowance - assetsDeposit, _delta_, "allowance");
        }
      } else {
        // We don't need to transfer assets to the vault to fulfill mint
        assertApproxEqAbs(newCallerAsset, oldCallerAsset, _delta_, "asset");
        assertApproxEqAbs(newVaultAsset, oldVaultAsset - assets, _delta_, "vault asset");
        assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

        if (oldAllowance != type(uint).max) {
          assertApproxEqAbs(newAllowance, oldAllowance, _delta_, "allowance");
        }
      }
    } else {
      // No assets in the vault, we need to transfer assets to the vault
      assertApproxEqAbs(newCallerAsset, oldCallerAsset - assets, _delta_, "asset");
      assertApproxEqAbs(newVaultAsset, oldVaultAsset, _delta_, "vault asset");
      assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "share");

      if (oldAllowance != type(uint).max) {
        assertApproxEqAbs(newAllowance, oldAllowance - assets, _delta_, "allowance");
      }
    }
  }

  function test_mint(Init memory init, uint shares, uint allowance) public virtual override {
    setUpVault(init);
    address caller = init.user[0];
    address receiver = init.user[1];
    shares = bound(shares, 0, _max_mint(caller));
    _approve(_underlying_, caller, _vault_, allowance);
    propMint(caller, receiver, shares);
  }

  /* ============ Transfer ============ */
  function propTransfer(address caller, address receiver, address owner, uint shares) public {
    uint oldReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint oldOwnerShare = IERC20(_vault_).balanceOf(owner);
    uint oldAllowance = IERC20(_vault_).allowance(owner, caller);

    vm.prank(caller);
    _call_vault(abi.encodeWithSelector(IERC20.transferFrom.selector, owner, receiver, shares));

    uint newReceiverShare = IERC20(_vault_).balanceOf(receiver);
    uint newOwnerShare = IERC20(_vault_).balanceOf(owner);
    uint newAllowance = IERC20(_vault_).allowance(owner, caller);

    if (owner != receiver) {
      assertApproxEqAbs(newOwnerShare, oldOwnerShare - shares, _delta_, "owner shares");
      assertApproxEqAbs(newReceiverShare, oldReceiverShare + shares, _delta_, "receiver shares");
    } else if (owner == receiver) {
      assertApproxEqAbs(newOwnerShare, oldOwnerShare, _delta_, "owner shares");
      assertApproxEqAbs(newReceiverShare, oldReceiverShare, _delta_, "receiver shares");
    }

    if (caller != owner && oldAllowance != type(uint).max) {
      assertApproxEqAbs(newAllowance, oldAllowance - shares, _delta_, "allowance");
    }

    assertTrue(caller == owner || oldAllowance != 0 || shares == 0, "access control");
  }

  function test_transfer(Init memory init, uint shares, uint allowance) public virtual {
    setUpVault(init);
    address caller = init.user[0];
    address receiver = init.user[1];
    address owner = init.user[2];
    shares = bound(shares, 0, _max_mint(owner));
    _approve(_vault_, owner, caller, allowance);
    propTransfer(caller, receiver, owner, shares);
  }

  /* ============ availableBalanceOf ============ */
  function propAvailableBalanceOf(address caller) public {
    vm.prank(caller);

    uint256 availableBalanceOf = _call_vault(
      abi.encodeWithSelector(Vault.availableBalanceOf.selector, _vault_)
    );

    uint256 totalAssets = _call_vault(abi.encodeWithSelector(Vault.totalAssets.selector));
    uint256 withdrawableAssets = yieldVault.convertToAssets(yieldVault.balanceOf(_vault_));

    if (withdrawableAssets >= totalAssets) {
      assertApproxEqAbs(availableBalanceOf, withdrawableAssets - totalAssets, _delta_, "yield");
    } else {
      assertApproxEqAbs(availableBalanceOf, underlyingToken.balanceOf(_vault_), _delta_, "yield");
    }
  }

  function test_availableBalanceOf(Init memory init, uint shares) public virtual {
    setUpVault(init);

    // We mint underlying assets to the YieldVault to generate yield
    uint256 yield = bound(shares, 0, 10000 * 1000);
    underlyingToken.mint(address(yieldVault), yield);

    console2.log("yield", yield);

    address caller = init.user[0];
    shares = bound(shares, 0, _max_mint(caller));
    propAvailableBalanceOf(caller);
  }

  /* ============ targetOf ============ */
  function testTargetOf() public {
    address target = vault.targetOf(address(prizeToken));
    assertEq(target, address(prizePool));
  }

  function testTargetOfFail() public {
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
    address newClaimer = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vm.expectEmit(true, true, true, true);
    emit ClaimerSet(address(this), newClaimer);

    address _newClaimer = vault.setClaimer(newClaimer);

    assertEq(_newClaimer, newClaimer);
  }

  function testSetClaimerOnlyOwner() public {
    address newClaimer = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vm.prank(newClaimer);

    vm.expectRevert(bytes("Ownable/caller-not-owner"));
    vault.setClaimer(newClaimer);

    vm.stopPrank();
  }

  /* ============ claimPrize ============ */
  function testClaimPrize() public {
    vm.warp(prizePool.drawStartedAt() + drawPeriodSeconds);
    prizePool.completeAndStartNextDraw(winningRandomNumber);

    address user = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

    vault.claimPrize(user, uint8(1));
  }
}

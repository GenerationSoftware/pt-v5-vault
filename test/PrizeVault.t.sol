// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { console2 } from "forge-std/Test.sol";
import { ERC4626Test, IMockERC20 } from "erc4626-tests/ERC4626.test.sol";
import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock, IERC20Metadata } from "openzeppelin/mocks/ERC20Mock.sol";

import { LiquidationPair } from "v5-liquidator/src/LiquidationPair.sol";
import { UFixed32x9 } from "v5-liquidator/src/libraries/FixedMathLib.sol";

import { MockLiquidationPairYieldSource, ILiquidationSource } from "v5-liquidator/test/mocks/MockLiquidationPairYieldSource.sol";

import { TwabController } from "v5-twab-controller/TwabController.sol";

import { PrizeVault } from "src/PrizeVault.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract PrizeVaultTest is ERC4626Test {
  /* ============ Events ============ */

  event NewPrizeVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TwabController twabController,
    IERC4626 indexed yieldVault,
    LiquidationPair indexed liquidationPair
  );

  /* ============ Variables ============ */

  string public prizeVaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public prizeVaultSymbol = "PTaEthDAI";

  IERC4626 public yieldVault;
  ERC20Mock public underlyingToken;
  ERC20Mock public reserveToken;

  LiquidationPair public liquidationPair;
  address public liquidationPairTarget = 0xcbE704e38ddB2E6A8bA9f4d335f2637132C20113;

  TwabController public twabController;

  /* ============ Setup ============ */

  function setUp() public override {
    underlyingToken = new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0);
    _underlying_ = address(underlyingToken);

    reserveToken = new ERC20Mock("PoolTogether", "POOL", address(this), 0);

    ILiquidationSource liquidationSource = new MockLiquidationPairYieldSource();

    liquidationPair = new LiquidationPair(
      msg.sender,
      liquidationSource,
      liquidationPairTarget,
      underlyingToken,
      reserveToken,
      UFixed32x9.wrap(0.3e9),
      UFixed32x9.wrap(0.02e9),
      100,
      50
    );

    twabController = new TwabController();

    yieldVault = new YieldVault(
      underlyingToken,
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    _vault_ = address(
      new PrizeVault(
        underlyingToken,
        prizeVaultName,
        prizeVaultSymbol,
        twabController,
        yieldVault,
        liquidationPair
      )
    );

    _delta_ = 0;
    _vaultMayBeEmpty = false;
    _unlimitedAmount = true;
  }

  /* ============ Constructor ============ */

  function testConstructor() public {
    vm.expectEmit(true, true, true, true);
    emit NewPrizeVault(
      IERC20(_underlying_),
      prizeVaultName,
      prizeVaultSymbol,
      twabController,
      yieldVault,
      liquidationPair
    );

    PrizeVault testPrizeVault = new PrizeVault(
      IERC20(_underlying_),
      prizeVaultName,
      prizeVaultSymbol,
      twabController,
      yieldVault,
      liquidationPair
    );

    assertEq(testPrizeVault.asset(), _underlying_);
    assertEq(testPrizeVault.name(), prizeVaultName);
    assertEq(testPrizeVault.symbol(), prizeVaultSymbol);
    assertEq(testPrizeVault.decimals(), ERC20(_underlying_).decimals());
    assertEq(testPrizeVault.twabController(), address(twabController));
    assertEq(testPrizeVault.yieldVault(), address(yieldVault));
    assertEq(testPrizeVault.liquidationPair(), address(liquidationPair));
  }

  function testConstructorTwabControllerZero() external {
    vm.expectRevert(bytes("PV/twabCtrlr-not-zero-address"));

    new PrizeVault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      TwabController(address(0)),
      yieldVault,
      liquidationPair
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("PV/yieldVault-not-zero-address"));

    new PrizeVault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      IERC4626(address(0)),
      liquidationPair
    );
  }

  function testConstructorLiquidationPairZero() external {
    vm.expectRevert(bytes("PV/LP-not-zero-address"));

    new PrizeVault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      LiquidationPair(address(0))
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
  function propAvailableBalanceOf(address caller, uint256 yield) public {
    vm.prank(caller);

    uint256 availableBalanceOf = _call_vault(
      abi.encodeWithSelector(PrizeVault.availableBalanceOf.selector, _vault_)
    );

    uint256 totalAssets = _call_vault(abi.encodeWithSelector(PrizeVault.totalAssets.selector));
    uint256 withdrawableAssets = yieldVault.maxWithdraw(_vault_);

    if (totalAssets > withdrawableAssets) {
      assertApproxEqAbs(availableBalanceOf, totalAssets - withdrawableAssets, _delta_, "yield");
    } else {
      assertApproxEqAbs(availableBalanceOf, withdrawableAssets - totalAssets, _delta_, "yield");
    }
  }

  function test_availableBalanceOf(Init memory init, uint shares, uint allowance) public virtual {
    setUpVault(init);

    // We mint underlying assets to the YieldVault to generate yield
    uint256 yield = bound(shares, 0, 10000 * 1000);
    underlyingToken.mint(address(yieldVault), yield);

    address caller = init.user[0];
    shares = bound(shares, 0, _max_mint(caller));
    propAvailableBalanceOf(caller, yield);
  }
}

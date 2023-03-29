// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";

import { LiquidationPair } from "v5-liquidator/LiquidationPair.sol";
import { PrizePool } from "v5-prize-pool/PrizePool.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";
import { Claimer } from "v5-vrgda-claimer/Claimer.sol";

import { Vault } from "src/Vault.sol";

import { LiquidationPairMock } from "test/contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "test/contracts/mock/LiquidationRouterMock.sol";
import { PrizePoolMock } from "test/contracts/mock/PrizePoolMock.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract VaultFuzzTest is ERC4626Test {
  /* ============ Variables ============ */
  Vault public vault;

  IERC4626 public yieldVault;
  ERC20Mock public underlyingAsset;
  ERC20Mock public prizeToken;

  LiquidationRouterMock public liquidationRouter;
  LiquidationPairMock public liquidationPair;

  PrizePoolMock public prizePool;

  uint256 public winningRandomNumber = 123456;
  uint32 public drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ Setup ============ */

  function setUp() public override {
    underlyingAsset = new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0);
    _underlying_ = address(underlyingAsset);

    prizeToken = new ERC20Mock("PoolTogether", "POOL", address(this), 0);

    twabController = new TwabController();

    prizePool = new PrizePoolMock(prizeToken);

    yieldVault = new YieldVault(
      underlyingAsset,
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    vault = new Vault(
      underlyingAsset,
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      yieldVault,
      PrizePool(address(prizePool)),
      Claimer(address(0x2faD9255711A4d22C35a003b3E723D9271aeA51d)),
      address(this)
    );

    _vault_ = address(vault);

    liquidationPair = new LiquidationPairMock(
      address(vault),
      address(prizePool),
      address(prizeToken),
      address(vault)
    );

    liquidationRouter = new LiquidationRouterMock();

    _delta_ = 0;
    _vaultMayBeEmpty = false;
    _unlimitedAmount = true;
  }

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
  function propAvailableBalanceOf() public {
    uint256 availableBalanceOf = _call_vault(
      abi.encodeWithSelector(Vault.availableBalanceOf.selector, _vault_)
    );

    uint256 totalAssets = _call_vault(abi.encodeWithSelector(Vault.totalAssets.selector));
    uint256 withdrawableAssets = yieldVault.convertToAssets(yieldVault.balanceOf(_vault_));

    if (withdrawableAssets >= totalAssets) {
      assertApproxEqAbs(availableBalanceOf, withdrawableAssets - totalAssets, _delta_, "yield");
    } else {
      assertApproxEqAbs(availableBalanceOf, underlyingAsset.balanceOf(_vault_), _delta_, "yield");
    }
  }

  function test_availableBalanceOf(Init memory init, uint shares) public virtual {
    setUpVault(init);

    address caller = init.user[0];
    shares = bound(shares, 0, _max_mint(caller));

    propAvailableBalanceOf();
  }

  /* ============ liquidate ============ */
  function propLiquidate(address caller) public {
    vm.startPrank(caller);

    // We divide by 2 cause not enough virtual liquidity has accrued to be able to liquidate the full amount
    uint256 _amountOut = _call_vault(
      abi.encodeWithSelector(Vault.availableBalanceOf.selector, _vault_)
    ) / 2;

    uint256 callerPrizeTokenBalanceBefore = prizeToken.balanceOf(caller);
    uint256 callerVaultSharesBalanceBefore = vault.balanceOf(caller);
    uint256 vaultAvailableBalanceBefore = vault.availableBalanceOf(_vault_);

    prizeToken.approve(address(liquidationRouter), type(uint256).max);

    uint256 exactAmountIn = liquidationRouter.swapExactAmountOut(
      liquidationPair,
      caller,
      _amountOut,
      type(uint256).max
    );

    assertApproxEqAbs(
      prizeToken.balanceOf(caller),
      callerPrizeTokenBalanceBefore - exactAmountIn,
      _delta_,
      "caller prizeToken balance"
    );

    assertApproxEqAbs(
      prizeToken.balanceOf(address(prizePool)),
      exactAmountIn,
      _delta_,
      "prizePool prizeToken balance"
    );

    uint256 callerVaultSharesBalanceAfter = vault.balanceOf(caller);

    assertApproxEqAbs(
      callerVaultSharesBalanceAfter,
      callerVaultSharesBalanceBefore + _amountOut,
      _delta_,
      "caller shares balance before withdraw"
    );

    assertApproxEqAbs(
      vault.availableBalanceOf(_vault_),
      vaultAvailableBalanceBefore,
      _delta_,
      "vault shares balance before withdraw"
    );

    vm.stopPrank();
  }

  function test_liquidate(Init memory init, uint shares) public virtual {
    init.yield = 0;
    setUpVault(init);

    vault.setLiquidationPair(LiquidationPair(address(liquidationPair)));

    address caller = init.user[0];

    // We mint underlying assets to the YieldVault to generate yield
    uint256 yield = bound(shares, 100, 10000 * 1000);
    underlyingAsset.mint(address(yieldVault), yield);

    prizeToken.mint(caller, type(uint256).max);

    shares = bound(shares, 10, _max_mint(caller));
    propLiquidate(caller);
  }
}

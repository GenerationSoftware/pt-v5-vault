// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { ERC4626Test } from "erc4626-tests/ERC4626.test.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20, IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock, IERC20Metadata } from "openzeppelin/mocks/ERC20Mock.sol";

import { PrizeVault } from "src/PrizeVault.sol";
import { ITWABController, TWABController } from "test/contracts/mock/TWABController.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";

contract PrizeVaultTest is ERC4626Test {
  /* ============ Events ============ */

  event NewPrizeVault(
    IERC20 indexed asset,
    string name,
    string symbol,
    TWABController indexed twabController,
    IERC4626 indexed yieldVault
  );

  /* ============ Variables ============ */

  // ERC20 public asset;

  string public prizeVaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public prizeVaultSymbol = "PTaEthDAI";

  TWABController public twabController;

  IERC4626 public yieldVault;
  string public yieldVaultName = "PoolTogether aEthDAI Yield (PTaEthDAIY)";
  string public yieldVaultSymbol = "PTaEthDAIY";

  /* ============ Setup ============ */

  function setUp() public override {
    _underlying_ = address(new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0));

    twabController = new TWABController();

    yieldVault = new YieldVault(IERC20Metadata(_underlying_), yieldVaultName, yieldVaultSymbol);

    _vault_ = address(
      new PrizeVault(
        IERC20(_underlying_),
        prizeVaultName,
        prizeVaultSymbol,
        twabController,
        yieldVault
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
      yieldVault
    );

    PrizeVault testPrizeVault = new PrizeVault(
      IERC20(_underlying_),
      prizeVaultName,
      prizeVaultSymbol,
      twabController,
      yieldVault
    );

    assertEq(testPrizeVault.asset(), _underlying_);
    assertEq(testPrizeVault.name(), prizeVaultName);
    assertEq(testPrizeVault.symbol(), prizeVaultSymbol);
    assertEq(testPrizeVault.decimals(), ERC20(_underlying_).decimals());
    assertEq(testPrizeVault.twabController(), address(twabController));
    assertEq(testPrizeVault.yieldVault(), address(yieldVault));
  }

  function testConstructorTWABControllerZero() external {
    vm.expectRevert(bytes("PV/twabCtrlr-not-zero-address"));

    new PrizeVault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      TWABController(address(0)),
      yieldVault
    );
  }

  function testConstructorYieldVaultZero() external {
    vm.expectRevert(bytes("PV/yieldVault-not-zero-address"));

    new PrizeVault(
      IERC20(_underlying_),
      "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
      "PTaEthDAI",
      twabController,
      IERC4626(address(0))
    );
  }

  /* ============ External functions ============ */

  function prop_transfer(address caller, address receiver, address owner, uint shares) public {
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
    prop_transfer(caller, receiver, owner, shares);
  }
}

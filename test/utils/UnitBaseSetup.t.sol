// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { PrizePool, SD59x18 } from "v5-prize-pool/PrizePool.sol";
import { ud2x18 } from "prb-math/UD2x18.sol";
import { sd1x18 } from "prb-math/SD1x18.sol";
import { TwabController } from "v5-twab-controller/TwabController.sol";
import { Claimer, IVault } from "v5-vrgda-claimer/Claimer.sol";
import { ILiquidationSource } from "v5-liquidator/interfaces/ILiquidationSource.sol";
import { LiquidationPair } from "v5-liquidator/LiquidationPair.sol";
import { LiquidationPairFactory } from "v5-liquidator/LiquidationPairFactory.sol";
import { LiquidationRouter } from "v5-liquidator/LiquidationRouter.sol";
import { UFixed32x9 } from "v5-liquidator-libraries/FixedMathLib.sol";

import { Vault } from "src/Vault.sol";
import { YieldVault } from "test/contracts/mock/YieldVault.sol";
import { Utils } from "test/utils/Utils.t.sol";

contract UnitBaseSetup is Test {
  /* ============ Variables ============ */
  Utils internal utils;

  address payable[] internal users;
  address internal owner;
  address internal manager;
  address internal alice;
  address internal bob;

  address public constant SPONSORSHIP_ADDRESS = address(1);

  Vault public vault;
  string public vaultName = "PoolTogether aEthDAI Prize Token (PTaEthDAI)";
  string public vaultSymbol = "PTaEthDAI";

  YieldVault public yieldVault;
  ERC20Mock public underlyingAsset;
  ERC20Mock public prizeToken;

  LiquidationRouter public liquidationRouter;
  LiquidationPair public liquidationPair;

  Claimer public claimer;
  PrizePool public prizePool;

  uint256 public winningRandomNumber = 123456;
  uint32 public drawPeriodSeconds = 1 days;
  TwabController public twabController;

  /* ============ setUp ============ */
  function setUp() public virtual {
    utils = new Utils();

    users = utils.createUsers(4);
    owner = users[0];
    manager = users[1];
    alice = users[2];
    bob = users[3];

    vm.label(owner, "Owner");
    vm.label(manager, "Manager");
    vm.label(alice, "Alice");
    vm.label(bob, "Bob");

    underlyingAsset = new ERC20Mock("Dai Stablecoin", "DAI", address(this), 0);

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
      underlyingAsset,
      "PoolTogether aEthDAI Yield (PTaEthDAIY)",
      "PTaEthDAIY"
    );

    vault = new Vault(
      underlyingAsset,
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
      100e18,
      50e18
    );

    vault.setLiquidationPair(liquidationPair);

    liquidationRouter = new LiquidationRouter(new LiquidationPairFactory());
  }
}

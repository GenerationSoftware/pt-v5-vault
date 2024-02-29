// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { IERC20, UnitBaseSetup, PrizeVault } from "./UnitBaseSetup.t.sol";

contract AaveV3WhilePaused is UnitBaseSetup {

    address yUSDCe = address(0xb02e7F2B2f6c983f89d08fE9936971a0a7Eca653); // yield vault
    address USDCeWhale = address(0xacD03D601e5bB1B275Bb94076fF46ED9D753435A);
    IERC20 USDCe;

    uint256 prePausedFork;
    uint256 prePausedBlock = 111754098;
    uint256 prePausedTimestamp = 1699106973;

    uint256 pausedFork;
    uint256 pausedBlock = 111847684;
    uint256 pausedTimestamp = 1699294145;

    // Uniswap Structs:

    struct ReserveData {
        //stores the reserve configuration
        ReserveConfigurationMap configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //aToken address
        address aTokenAddress;
        //stableDebtToken address
        address stableDebtTokenAddress;
        //variableDebtToken address
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the current treasury balance, scaled
        uint128 accruedToTreasury;
        //the outstanding unbacked aTokens minted through the bridging feature
        uint128 unbacked;
        //the outstanding debt borrowed against this asset in isolation mode
        uint128 isolationModeTotalDebt;
    }

    struct ReserveConfigurationMap {
        //bit 0-15: LTV
        //bit 16-31: Liq. threshold
        //bit 32-47: Liq. bonus
        //bit 48-55: Decimals
        //bit 56: reserve is active
        //bit 57: reserve is frozen
        //bit 58: borrowing is enabled
        //bit 59: stable rate borrowing enabled
        //bit 60: asset is paused
        //bit 61: borrowing in isolation mode is enabled
        //bit 62: siloed borrowing enabled
        //bit 63: flashloaning enabled
        //bit 64-79: reserve factor
        //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
        //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
        //bit 152-167 liquidation protocol fee
        //bit 168-175 eMode category
        //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
        //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
        //bit 252-255 unused

        uint256 data;
    }

    /* ============ setup ============ */

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(yUSDCe);
    }

    function setUp() public virtual override {
        prePausedFork = vm.createFork(vm.rpcUrl("optimism"), prePausedBlock);
        pausedFork = vm.createFork(vm.rpcUrl("optimism"), pausedBlock);

        // select pre-paused fork and setup
        vm.selectFork(prePausedFork);
        vm.warp(prePausedTimestamp);
        super.setUp();
        USDCe = IERC20(vault.asset());

        // fill yield buffer
        dealAssets(address(vault), vault.yieldBuffer());

        // console2.log("block", block.number);
        // console2.log("timestamp", block.timestamp);

        // (bool success, bytes memory data) = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD).call(abi.encodeWithSignature("getReserveData(address)", address(USDCe)));
        // ReserveData memory reserveData = abi.decode(data, (ReserveData));
        // console2.log("last updated", reserveData.lastUpdateTimestamp);

        // make initial deposits
        dealAssets(alice, 1000e6);
        vm.startPrank(alice);
        USDCe.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);
        vm.stopPrank();

        dealAssets(bob, 10000e6);
        vm.startPrank(bob);
        USDCe.approve(address(vault), 10000e6);
        vault.deposit(10000e6, bob);
        vm.stopPrank();

        // make wallets and vault persistent
        vm.makePersistent(alice);
        vm.makePersistent(bob);
        vm.makePersistent(address(vault));
        vm.makePersistent(yUSDCe);
        vm.makePersistent(address(USDCe));
        vm.makePersistent(address(0x625E7708f30cA75bfd92586e17077590C60eb4cD)); // aUSDCe
        vm.makePersistent(address(vault.twabController()));

        // switch to paused state
        vm.selectFork(pausedFork);
        vm.warp(pausedTimestamp);

        (bool success, bytes memory data) = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD).call(abi.encodeWithSignature("getReserveData(address)", address(USDCe)));
        ReserveData memory reserveData = abi.decode(data, (ReserveData));
        assertEq(reserveData.configuration.data >> 60 & 1, 1); // assert asset is paused
    }

    function dealAssets(address to, uint256 amount) internal {
        vm.startPrank(USDCeWhale);
        USDCe.transfer(to, amount);
        vm.stopPrank();
    }

    function testSetUp() external {
        assertEq(vault.balanceOf(alice), 1000e6);
        assertEq(vault.balanceOf(bob), 10000e6);
        assertEq(vault.currentYieldBuffer(), vault.yieldBuffer());
    }

    /* ============ deposits ============ */
        
    function testDepositFails() external {
        dealAssets(alice, 1000e6);
        vm.startPrank(alice);
        // Preview is still ok. This doesn't break 4626 spec since it does have to revert if the actual deposit will revert
        assertEq(vault.previewDeposit(1000e6), 1000e6);
        USDCe.approve(address(vault), 1000e6);
        vm.expectRevert();
        vault.deposit(1000e6, alice);
        vm.stopPrank();
    }

    function testMintFails() external {
        dealAssets(alice, 1000e6);
        vm.startPrank(alice);
        // Preview is still ok. This doesn't break 4626 spec since it does have to revert if the actual deposit will revert
        assertEq(vault.previewMint(1000e6), 1000e6);
        USDCe.approve(address(vault), 1000e6);
        vm.expectRevert();
        vault.mint(1000e6, alice);
        vm.stopPrank();
    }

    function testMaxDepositZero() external {
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxDeposit(bob), 0);
    }

    function testMaxMintZero() external {
        assertEq(vault.maxMint(alice), 0);
        assertEq(vault.maxMint(bob), 0);
    }

    /* ============ withdrawals ============ */

    function testMaxWithdrawZero() external {
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxWithdraw(bob), 0);
    }

    function testMaxRedeemZero() external {
        assertEq(vault.maxRedeem(alice), 0);
        assertEq(vault.maxRedeem(bob), 0);
    }

    function testWithdrawFails() external {
        vm.startPrank(alice);
        // preview and conversion should still return accurate values even though the withdraw will fail
        assertEq(vault.previewWithdraw(1000e6), 1000e6);
        assertEq(vault.convertToAssets(1000e6), 1000e6);
        vm.expectRevert();
        vault.withdraw(1000e6, alice, alice);
        vm.stopPrank();
    }

    function testRedeemFails() external {
        vm.startPrank(alice);
        // preview and conversion should still return accurate values even though the redeem will fail
        assertEq(vault.previewRedeem(1000e6), 1000e6);
        assertEq(vault.convertToShares(1000e6), 1000e6);
        vm.expectRevert();
        vault.redeem(1000e6, alice, alice);
        vm.stopPrank();
    }

    function testWithdrawSucceedsIfLatentBalanceIsEnough() external {
        assertEq(USDCe.balanceOf(address(vault)), 0);

        // send latent assets directly to the vault
        dealAssets(address(vault), 1e6);

        vm.startPrank(alice);
        assertEq(vault.maxWithdraw(alice), 1e6);
        assertEq(vault.previewWithdraw(1e6), 1e6);
        assertEq(vault.convertToAssets(1e6), 1e6);
        vault.withdraw(1e6, alice, alice);
        vm.stopPrank();

        assertEq(USDCe.balanceOf(alice), 1e6);
    }

    function testRedeemSucceedsIfLatentBalanceIsEnough() external {
        assertEq(USDCe.balanceOf(address(vault)), 0);

        // send latent assets directly to the vault
        dealAssets(address(vault), 1e6);

        vm.startPrank(alice);
        assertEq(vault.maxRedeem(alice), 1e6);
        assertEq(vault.previewRedeem(1e6), 1e6);
        assertEq(vault.convertToShares(1e6), 1e6);
        vault.redeem(1e6, alice, alice);
        vm.stopPrank();

        assertEq(USDCe.balanceOf(alice), 1e6);
    }

    /* ============ liquidations ============ */

    // liquidating shares doesn't require the assets to be withdrawn from aave, so this will still work when paused.
    function testLiquidateSharesSucceeds() external {
        // accrue yield by letting time pass
        uint256 totalAssetsBefore = vault.totalAssets();
        vm.warp(block.timestamp + 60 * 60 * 24);
        uint256 totalAssetsAfter = vault.totalAssets();
        assertGt(totalAssetsAfter, totalAssetsBefore);

        // check share liquidation
        uint256 liquidShares = vault.liquidatableBalanceOf(address(vault));
        assertGt(liquidShares, 0);

        vm.startPrank(vault.liquidationPair());
        vault.transferTokensOut(address(0), address(this), address(vault), liquidShares);
        vm.stopPrank();

        assertEq(vault.balanceOf(address(this)), liquidShares);
        assertEq(vault.liquidatableBalanceOf(address(vault)), 0);
    }

    // liquidating assets requires that the assets are able to be withdrawn, which is not the case when paused.
    function testLiquidatableAssetsZero() external {
        // accrue yield by letting time pass
        uint256 totalAssetsBefore = vault.totalAssets();
        vm.warp(block.timestamp + 60 * 60 * 24);
        uint256 totalAssetsAfter = vault.totalAssets();
        assertGt(totalAssetsAfter, totalAssetsBefore);

        // check asset liquidation
        uint256 liquidAssets = vault.liquidatableBalanceOf(address(USDCe));
        assertEq(liquidAssets, 0);

        vm.startPrank(vault.liquidationPair());
        vm.expectRevert();
        vault.transferTokensOut(address(0), address(this), address(USDCe), 1);
        vm.stopPrank();
    }

    // if there is a latent balance in the vault, then these assets can still be liquidated
    function testLiquidateAssetsSucceedsIfFromLatentBalance() external {
        // send latent assets to vault
        dealAssets(address(vault), 1e6);

        // check asset liquidation
        uint256 liquidAssets = vault.liquidatableBalanceOf(address(USDCe));
        assertEq(liquidAssets, 1e6);

        vm.startPrank(vault.liquidationPair());
        vault.transferTokensOut(address(0), address(this), address(USDCe), liquidAssets);
        vm.stopPrank();

        assertEq(USDCe.balanceOf(address(this)), liquidAssets);
        assertEq(vault.liquidatableBalanceOf(address(USDCe)), 0);
    }

}
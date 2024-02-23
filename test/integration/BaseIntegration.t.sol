// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC20, IERC4626 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { ERC20PermitMock } from "../contracts/mock/ERC20PermitMock.sol";
import { PrizePoolMock } from "../contracts/mock/PrizePoolMock.sol";
import { Permit } from "../contracts/utility/Permit.sol";

import { PrizeVaultWrapper, PrizeVault } from "../contracts/wrapper/PrizeVaultWrapper.sol";

abstract contract BaseIntegration is Test, Permit {

    /* ============ events ============ */

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event ClaimerSet(address indexed claimer);
    event LiquidationPairSet(address indexed tokenOut, address indexed liquidationPair);
    event YieldFeeRecipientSet(address indexed yieldFeeRecipient);
    event YieldFeePercentageSet(uint256 yieldFeePercentage);
    event MockContribute(address prizeVault, uint256 amount);
    event ClaimYieldFeeShares(address indexed recipient, uint256 shares);
    event TransferYieldOut(address indexed liquidationPair, address indexed tokenOut, address indexed recipient, uint256 amountOut, uint256 yieldFee);
    event Sponsor(address indexed caller, uint256 assets, uint256 shares);

    /* ============ variables ============ */

    address internal owner;
    uint256 internal ownerPrivateKey;

    address internal alice;
    uint256 internal alicePrivateKey;

    address internal bob;
    uint256 internal bobPrivateKey;

    PrizeVaultWrapper public prizeVault;
    string public vaultName = "PoolTogether Test Vault";
    string public vaultSymbol = "pTest";
    uint256 public yieldBuffer = 1e5;

    IERC4626 public yieldVault;
    IERC20 public underlyingAsset;
    uint8 public assetDecimals;
    uint256 public approxAssetUsdExchangeRate;
    ERC20PermitMock public prizeToken;

    address public claimer;
    PrizePoolMock public prizePool;

    uint32 public drawPeriodSeconds = 1 days;
    TwabController public twabController;

    /// @dev A low gas estimate of what it would cost in gas to manipulate the state into losing 1 wei of assets
    /// in a rounding error. (This should be a unachievable low estimate such that an attacker would never be able
    /// to cause repeated rounding errors for less).
    uint256 lowGasEstimateForStateChange = 100_000;

    /// @dev A low gas price estimate for the chain.
    uint256 lowGasPriceEstimate = 7 gwei;

    /// @dev Defined in 1e18 precision. (2e18 would be 2 ETH per USD)
    uint256 approxEthUsdExchangeRate = uint256(1e18) / uint256(3000); // approx 1 ETH for $3000

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate);

    function setUpYieldVault() public virtual returns (IERC4626);

    function setUpFork() public virtual;

    function beforeSetup() public virtual;

    function afterSetup() public virtual;

    function setUp() public virtual {
        beforeSetup();

        (owner, ownerPrivateKey) = makeAddrAndKey("Owner");
        (alice, alicePrivateKey) = makeAddrAndKey("Alice");
        (bob, bobPrivateKey) = makeAddrAndKey("Bob");

        setUpFork();
        (underlyingAsset, assetDecimals, approxAssetUsdExchangeRate) = setUpUnderlyingAsset();
        yieldVault = setUpYieldVault();

        prizeToken = new ERC20PermitMock("PoolTogether");

        twabController = new TwabController(1 hours, uint32(block.timestamp));

        prizePool = new PrizePoolMock(prizeToken, twabController);

        claimer = address(0xe291d9169F0316272482dD82bF297BB0a11D267f);

        prizeVault = new PrizeVaultWrapper(
            vaultName,
            vaultSymbol,
            yieldVault,
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            0,
            yieldBuffer, // yield buffer
            address(this)
        );

        // Fill yield buffer if non-zero:
        if (yieldBuffer > 0) {
            dealAssets(address(prizeVault), yieldBuffer);
        }

        afterSetup();
    }

    /* ============ prank helpers ============ */

    address private currentPrankee;

    /// @notice should be used instead of vm.startPrank so we can keep track of pranks within other pranks
    function startPrank(address prankee) public {
        currentPrankee = prankee;
        vm.startPrank(prankee);
    }

    /// @notice should be used instead of vm.stopPrank so we can keep track of pranks within other pranks
    function stopPrank() public {
        currentPrankee = address(0);
        vm.stopPrank();
    }

    /// @notice pranks the address and sets the prank back to the msg sender at the end
    modifier prankception(address prankee) {
        address prankBefore = currentPrankee;
        vm.stopPrank();
        vm.startPrank(prankee);
        _;
        vm.stopPrank();
        if (prankBefore != address(0)) {
            vm.startPrank(prankBefore);
        }
    }

    /* ============ helpers to override ============ */

    /// @dev The max amount of assets than can be dealt.
    function maxDeal() public virtual returns (uint256);

    /// @dev May revert if the amount requested exceeds the amount available to deal.
    function dealAssets(address to, uint256 amount) public virtual;

    /// @dev Some yield sources accrue by time, so it's difficult to accrue an exact amount. Call the 
    /// function multiple times if the test requires the accrual of more yield than the default amount.
    function _accrueYield() internal virtual;

    /// @dev Simulates loss on the yield vault such that the value of it's shares drops
    function _simulateLoss() internal virtual;

    /// @dev Each integration test must override the `_accrueYield` internal function for this to work.
    function accrueYield() public returns (uint256) {
        uint256 assetsBefore = prizeVault.totalAssets();
        _accrueYield();
        uint256 assetsAfter = prizeVault.totalAssets();
        // if (yieldVault.balanceOf(address(prizeVault)) > 0) {
        //     // if the prize vault has any yield vault shares, check to ensure yield has accrued
        //     require(assetsAfter > assetsBefore, "yield did not accrue");
        // } else {
        //     if (underlyingAsset.balanceOf(address(prizeVault)) > 0) {
        //         // the underlying asset might be rebasing in some setups, so it's possible time passing has caused an increase in latent balance
        //         require(assetsAfter >= assetsBefore, "assets decreased while holding latent balance");
        //     } else {
        //         // otherwise, we should expect no change on the prize vault
        //         require(assetsAfter == assetsBefore, "assets changed with zero yield shares");
        //     }
        // }
        return assetsAfter - assetsBefore;
    }

    /// @dev Each integration test must override the `_simulateLoss` internal function for this to work.
    /// @return The loss the prize vault has incurred as a result of yield vault loss (if any)
    function simulateLoss() public returns (uint256) {
        uint256 assetsBefore = prizeVault.totalAssets();
        _simulateLoss();
        uint256 assetsAfter = prizeVault.totalAssets();
        // if (yieldVault.balanceOf(address(prizeVault)) > 0) {
        //     // if the prize vault has any yield vault shares, check to ensure some loss has occurred
        //     require(assetsAfter < assetsBefore, "loss not simulated");
        // } else {
        //     if (underlyingAsset.balanceOf(address(prizeVault)) > 0) {
        //         // the underlying asset might be rebasing in some setups, so it's possible time passing has caused an increase in latent balance
        //         require(assetsAfter >= assetsBefore, "assets decreased while holding latent balance");
        //         return 0;
        //     } else {
        //         // otherwise, we should expect no change on the prize vault
        //         require(assetsAfter == assetsBefore, "assets changed with zero yield shares");
        //     }
        // }
        return assetsBefore - assetsAfter;
    }

    /* ============ Integration Test Scenarios ============ */

    //////////////////////////////////////////////////////////
    /// Basic Asset Tests
    //////////////////////////////////////////////////////////

    /// @dev Tests if the asset meets a minimum precision per dollar (PPD). If the asset
    /// is below this PPD, then it is possible that the yield buffer will not be able to sustain
    /// the rounding errors that will accrue on deposits and withdrawals.
    ///
    /// Also passes if the yield buffer is zero (no buffer is needed if rounding errors are impossible).
    function testAssetPrecisionMeetsMinimum() public {
        if (yieldBuffer > 0) {
            uint256 minimumPPD = 1e6; // USDC is the benchmark (6 decimals represent $1 of value)
            uint256 assetPPD = (1e18 * (10 ** assetDecimals)) / approxAssetUsdExchangeRate;
            assertGe(assetPPD, minimumPPD, "asset PPD > minimum PPD");
        }
    }

    /// @notice Test if the attacker can cause rounding error loss on the prize vault by spending
    /// less in gas than the rounding error loss will cost the vault.
    ///
    /// @dev This is an important measure to test since it's possible that some yield vaults can essentially
    /// rounding errors to other holders of yield vault shares. If an attacker can cheaply cause repeated
    /// rounding errors on the prize vault, they can potentially profit by being a majority shareholder on
    /// the underlying yield vault.
    function testAssetRoundingErrorManipulationCost() public {
        uint256 costToManipulateInEth = lowGasPriceEstimate * lowGasEstimateForStateChange;
        uint256 costToManipulateInUsd = (costToManipulateInEth * 1e18) / approxEthUsdExchangeRate;
        uint256 costOfRoundingErrorInUsd = 1e18 / approxAssetUsdExchangeRate;
        // 10x threshold is set so an attacker would have to spend at least 10x the loss they can cause on the prize vault.
        uint256 multiplierThreshold = 10;
        assertLt(costOfRoundingErrorInUsd * multiplierThreshold, costToManipulateInUsd, "attacker can cheaply cause rounding errors");
    }

    //////////////////////////////////////////////////////////
    /// Deposit Tests
    //////////////////////////////////////////////////////////

    /// @notice test deposit
    function testDeposit() public {
        uint256 amount = 10 ** assetDecimals;
        dealAssets(alice, amount);

        uint256 totalAssetsBefore = prizeVault.totalAssets();
        uint256 totalSupplyBefore = prizeVault.totalSupply();

        startPrank(alice);
        underlyingAsset.approve(address(prizeVault), amount);
        prizeVault.deposit(amount, alice);
        stopPrank();

        uint256 totalAssetsAfter = prizeVault.totalAssets();
        uint256 totalSupplyAfter = prizeVault.totalSupply();

        assertEq(prizeVault.balanceOf(alice), amount, "shares minted");
        assertApproxEqAbs(totalAssetsBefore + amount, totalAssetsAfter, 1, "assets accounted for with possible rounding error");
        assertEq(totalSupplyBefore + amount, totalSupplyAfter, "supply increased by amount");
    }

    /// @notice test multi-user deposit
    function testMultiDeposit() public {
        address[] memory depositors = new address[](3);
        depositors[0] = alice;
        depositors[1] = bob;
        depositors[2] = address(this);

        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 amount = (10 ** assetDecimals) * (i + 1);
            dealAssets(depositors[i], amount);

            uint256 totalAssetsBefore = prizeVault.totalAssets();
            uint256 totalSupplyBefore = prizeVault.totalSupply();

            startPrank(depositors[i]);
            underlyingAsset.approve(address(prizeVault), amount);
            prizeVault.deposit(amount, depositors[i]);
            stopPrank();

            uint256 totalAssetsAfter = prizeVault.totalAssets();
            uint256 totalSupplyAfter = prizeVault.totalSupply();

            assertEq(prizeVault.balanceOf(depositors[i]), amount, "shares minted");
            assertApproxEqAbs(totalAssetsBefore + amount, totalAssetsAfter, 1, "assets accounted for with possible rounding error");
            assertEq(totalSupplyBefore + amount, totalSupplyAfter, "supply increased by amount");
        }
    }

    /// @notice test multi-user deposit w/yield accrual in between
    function testMultiDepositWithYieldAccrual() public {
        address[] memory depositors = new address[](3);
        depositors[0] = alice;
        depositors[1] = bob;
        depositors[2] = address(this);

        for (uint256 i = 0; i < depositors.length; i++) {
            // accrue yield
            accrueYield();

            uint256 amount = (10 ** assetDecimals) * (i + 1);
            dealAssets(depositors[i], amount);

            uint256 totalAssetsBefore = prizeVault.totalAssets();
            uint256 totalSupplyBefore = prizeVault.totalSupply();

            startPrank(depositors[i]);
            underlyingAsset.approve(address(prizeVault), amount);
            prizeVault.deposit(amount, depositors[i]);
            stopPrank();

            uint256 totalAssetsAfter = prizeVault.totalAssets();
            uint256 totalSupplyAfter = prizeVault.totalSupply();

            assertEq(prizeVault.balanceOf(depositors[i]), amount, "shares minted");
            assertApproxEqAbs(totalAssetsBefore + amount, totalAssetsAfter, 1, "assets accounted for with possible rounding error");
            assertEq(totalSupplyBefore + amount, totalSupplyAfter, "supply increased by amount");
        }
    }

    //////////////////////////////////////////////////////////
    /// Withdrawal Tests
    //////////////////////////////////////////////////////////

    /// @notice test withdraw
    function testWithdraw() public {
        uint256 amount = 10 ** assetDecimals;
        dealAssets(alice, amount);

        uint256 totalAssetsBefore = prizeVault.totalAssets();
        uint256 totalSupplyBefore = prizeVault.totalSupply();

        startPrank(alice);
        underlyingAsset.approve(address(prizeVault), amount);
        prizeVault.deposit(amount, alice);
        prizeVault.withdraw(amount, alice, alice);
        stopPrank();

        uint256 totalAssetsAfter = prizeVault.totalAssets();
        uint256 totalSupplyAfter = prizeVault.totalSupply();

        assertEq(prizeVault.balanceOf(alice), 0, "burns all user shares on full withdraw");
        assertEq(underlyingAsset.balanceOf(alice), amount, "withdraws full amount of assets");
        assertApproxEqAbs(totalAssetsBefore, totalAssetsAfter, 2, "no assets missing except for possible rounding error"); // 1 possible rounding error for deposit, 1 for withdraw
        assertEq(totalSupplyBefore, totalSupplyAfter, "supply same as before");
    }

    /// @notice test withdraw with yield accrual
    function testWithdrawWithYieldAccrual() public {
        uint256 amount = 10 ** assetDecimals;
        dealAssets(alice, amount);

        uint256 totalAssetsBefore = prizeVault.totalAssets();
        uint256 totalSupplyBefore = prizeVault.totalSupply();

        startPrank(alice);
        underlyingAsset.approve(address(prizeVault), amount);
        prizeVault.deposit(amount, alice);
        uint256 yield = accrueYield(); // accrue yield in between
        prizeVault.withdraw(amount, alice, alice);
        stopPrank();

        uint256 totalAssetsAfter = prizeVault.totalAssets();
        uint256 totalSupplyAfter = prizeVault.totalSupply();

        assertEq(prizeVault.balanceOf(alice), 0, "burns all user shares on full withdraw");
        assertEq(underlyingAsset.balanceOf(alice), amount, "withdraws full amount of assets");
        assertApproxEqAbs(totalAssetsBefore + yield, totalAssetsAfter, 2, "no assets missing except for possible rounding error"); // 1 possible rounding error for deposit, 1 for withdraw
        assertEq(totalSupplyBefore, totalSupplyAfter, "supply same as before");
    }

    /// @notice test all users withdraw
    function testWithdrawAllUsers() public {
        address[] memory depositors = new address[](3);
        depositors[0] = alice;
        depositors[1] = bob;
        depositors[2] = address(this);

        // deposit
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 amount = (10 ** assetDecimals) * (i + 1);
            dealAssets(depositors[i], amount);

            startPrank(depositors[i]);
            underlyingAsset.approve(address(prizeVault), amount);
            prizeVault.deposit(amount, depositors[i]);
            stopPrank();
        }

        // withdraw
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 amount = (10 ** assetDecimals) * (i + 1);
            uint256 totalAssetsBefore = prizeVault.totalAssets();
            uint256 totalSupplyBefore = prizeVault.totalSupply();

            startPrank(depositors[i]);
            prizeVault.withdraw(amount, depositors[i], depositors[i]);
            stopPrank();

            uint256 totalAssetsAfter = prizeVault.totalAssets();
            uint256 totalSupplyAfter = prizeVault.totalSupply();

            assertEq(prizeVault.balanceOf(depositors[i]), 0, "burned all user's shares on withdraw");
            assertEq(underlyingAsset.balanceOf(depositors[i]), amount, "withdrew full asset amount for user");
            assertApproxEqAbs(totalAssetsBefore, totalAssetsAfter + amount, 1, "assets accounted for with no more than 1 wei rounding error");
            assertEq(totalSupplyBefore - amount, totalSupplyAfter, "total supply decreased by amount");
        }
    }

    /// @notice test all users withdraw during lossy state
    function testWithdrawAllUsersWhileLossy() public {
        address[] memory depositors = new address[](3);
        depositors[0] = alice;
        depositors[1] = bob;
        depositors[2] = address(this);

        // deposit
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 amount = (10 ** assetDecimals) * (i + 1);
            dealAssets(depositors[i], amount);

            startPrank(depositors[i]);
            underlyingAsset.approve(address(prizeVault), amount);
            prizeVault.deposit(amount, depositors[i]);
            stopPrank();
        }

        // cause loss on the yield vault
        simulateLoss();

        // ensure prize vault is in lossy state
        assertLt(prizeVault.totalAssets(), prizeVault.totalDebt());

        // verify all users can withdraw a proportional amount of assets
        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 shares = prizeVault.balanceOf(depositors[i]);
            uint256 totalAssetsBefore = prizeVault.totalAssets();
            uint256 totalSupplyBefore = prizeVault.totalSupply();
            uint256 totalDebtBefore = prizeVault.totalDebt();
            uint256 expectedAssets = (shares * totalAssetsBefore) / totalDebtBefore;

            startPrank(depositors[i]);
            uint256 assets = prizeVault.redeem(shares, depositors[i], depositors[i]);
            stopPrank();

            uint256 totalAssetsAfter = prizeVault.totalAssets();
            uint256 totalSupplyAfter = prizeVault.totalSupply();

            assertEq(assets, expectedAssets, "assets received proportional to shares / totalDebt");
            assertEq(prizeVault.balanceOf(depositors[i]), 0, "burned all user's shares on withdraw");
            assertEq(underlyingAsset.balanceOf(depositors[i]), assets, "withdrew assets for user");
            assertApproxEqAbs(totalAssetsBefore, totalAssetsAfter + assets, 1, "assets accounted for with no more than 1 wei rounding error");
            assertEq(totalSupplyBefore - shares, totalSupplyAfter, "total supply decreased by shares");
        }
    }

    /// @notice test yield vault loss

    /// @notice test liquidation of assets

    /// @notice test for yield vault deposit / withdraw fees

    //////////////////////////////////////////////////////////
    /// State Tests
    //////////////////////////////////////////////////////////

    /// @notice test liquidatable balance of when yield available

    /// @notice test liquidatable balance of when lossy
    
}

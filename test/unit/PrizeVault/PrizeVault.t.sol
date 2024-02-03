// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { UnitBaseSetup, PrizePool, TwabController, ERC20, IERC20, IERC4626 } from "./UnitBaseSetup.t.sol";
import { IVaultHooks, VaultHooks } from "../../../src/interfaces/IVaultHooks.sol";

import "../../../src/PrizeVault.sol";

contract PrizeVaultTest is UnitBaseSetup {

    /* ============ variables ============ */

    uint32 public constant YIELD_FEE_PERCENTAGE = 100000000; // 0.1 = 10%

    /* ============ constructor ============ */

    function testConstructor() public {
        PrizeVault testVault = new PrizeVault(
            vaultName,
            vaultSymbol,
            yieldVault,
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            YIELD_FEE_PERCENTAGE,
            1e6,
            address(this)
        );

        uint256 assetDecimals = ERC20(address(underlyingAsset)).decimals();

        assertEq(testVault.asset(), address(underlyingAsset));
        assertEq(testVault.name(), vaultName);
        assertEq(testVault.symbol(), vaultSymbol);
        assertEq(testVault.decimals(), assetDecimals);
        assertEq(address(testVault.twabController()), address(twabController));
        assertEq(address(testVault.yieldVault()), address(yieldVault));
        assertEq(address(testVault.prizePool()), address(prizePool));
        assertEq(testVault.claimer(), address(claimer));
        assertEq(testVault.owner(), address(this));
    }

    function testConstructorYieldVaultZero() external {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.YieldVaultZeroAddress.selector));

        new PrizeVault(
            "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
            "PTaEthDAI",
            IERC4626(address(0)),
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            YIELD_FEE_PERCENTAGE,
            1e6,
            address(this)
        );
    }

    function testFailConstructorPrizePoolZero() external {
        // Fails because `prizePool.twabController()` is not callable on the zero address
        new PrizeVault(
            "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
            "PTaEthDAI",
            yieldVault,
            PrizePool(address(0)),
            claimer,
            address(this),
            YIELD_FEE_PERCENTAGE,
            1e6,
            address(this)
        );
    }

    function testConstructorOwnerZero() external {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.OwnerZeroAddress.selector));

        new PrizeVault(
            "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
            "PTaEthDAI",
            yieldVault,
            PrizePool(address(prizePool)),
            claimer,
            address(this),
            YIELD_FEE_PERCENTAGE,
            1e6,
            address(0)
        );
    }

    function testConstructorClaimerZero() external {
        vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));

        new PrizeVault(
            "PoolTogether aEthDAI Prize Token (PTaEthDAI)",
            "PTaEthDAI",
            yieldVault,
            PrizePool(address(prizePool)),
            address(0),
            address(this),
            YIELD_FEE_PERCENTAGE,
            1e6,
            address(this)
        );
    }

    /* ============ totalDebt ============ */

    function testTotalDebt_IncreasesWithDepositsAndDecreasesWithWithdrawals() public {
        assertEq(vault.totalDebt(), 0);

        underlyingAsset.mint(alice, 1e18);

        vm.startPrank(alice);

        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        assertEq(vault.totalDebt(), 1e18);

        vault.withdraw(1e9, alice, alice);
        assertEq(vault.totalDebt(), 1e18 - 1e9);

        vault.withdraw(1e18 - 1e9, alice, alice);
        assertEq(vault.totalDebt(), 0);

        vm.stopPrank();
    }

    function testTotalDebt_IncreasesWithYieldFeeAccrualAndDecreasesWithFeeClaims() public {
        vault.setYieldFeePercentage(1e8); // 10%
        vault.setYieldFeeRecipient(bob);
        assertEq(vault.totalDebt(), 0);

        // make an initial deposit
        underlyingAsset.mint(alice, 1e18);
        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1e18);
        assertEq(vault.totalSupply(), 1e18);
        assertEq(vault.totalDebt(), 1e18);

        // mint yield to the vault and liquidate
        underlyingAsset.mint(address(vault), 1e18);
        vault.setLiquidationPair(address(this));
        uint256 maxLiquidation = vault.liquidatableBalanceOf(address(underlyingAsset));
        uint256 amountOut = maxLiquidation / 2;
        uint256 yieldFee = (1e18 - vault.yieldBuffer()) / (2 * 10); // 10% yield fee + 90% amountOut = 100%
        vault.transferTokensOut(address(0), bob, address(underlyingAsset), amountOut);

        assertEq(vault.totalAssets(), 1e18 + 1e18 - amountOut); // existing balance + yield - amountOut
        assertEq(vault.totalSupply(), 1e18); // no change in supply since liquidation was for assets
        assertEq(vault.totalDebt(), 1e18 + yieldFee); // debt increased since we reserved shares for the yield fee

        vm.startPrank(bob);
        vault.claimYieldFeeShares(yieldFee);
        assertEq(vault.totalDebt(), vault.totalSupply());
        assertEq(vault.yieldFeeBalance(), 0);
        vm.stopPrank();
    }

    /* ============ targetOf ============ */

    function testTargetOf() public {
        _setLiquidationPair();

        address target = vault.targetOf(address(prizeToken));
        assertEq(target, address(prizePool));
    }

    /* ============ getters ============ */

    function testGetYieldVault() external {
        assertEq(address(vault.yieldVault()), address(yieldVault));
    }

    function testGetLiquidationPair() external {
        vault.setLiquidationPair(address(liquidationPair));
        assertEq(address(vault.liquidationPair()), address(liquidationPair));
    }

    function testGetYieldFeeRecipient() external {
        assertEq(vault.yieldFeeRecipient(), address(this));
    }

    function testGetYieldFeePercentage() external {
        vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
        assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
    }

    /* ============ setClaimer ============ */

    function testSetClaimer() public {
        address _newClaimer = makeAddr("claimer");

        vm.expectEmit(true, true, true, true);
        emit ClaimerSet(_newClaimer);

        vault.setClaimer(_newClaimer);

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
        vm.expectRevert(abi.encodeWithSelector(Claimable.ClaimerZeroAddress.selector));
        vault.setClaimer(address(0));
    }

    /* ============ availableYieldBalance ============ */

    function testAvailableYieldBalance() public {
        // make an initial deposit so the vault holds some yield vault shares
        underlyingAsset.mint(alice, 1e18);
        vm.startPrank(alice);
        underlyingAsset.approve(address(vault), 1e18);
        vault.deposit(1e18, alice);
        vm.stopPrank();

        assertEq(vault.availableYieldBalance(), 0);

        uint256 yieldBuffer = vault.yieldBuffer();

        // no yield if it doesn't exceed yield buffer
        underlyingAsset.mint(address(yieldVault), yieldBuffer);
        assertEq(vault.availableYieldBalance(), 0);

        // now it does
        underlyingAsset.mint(address(yieldVault), 1e9);
        assertApproxEqAbs(vault.availableYieldBalance(), 1e9, 1); // 1 wei rounding error

        // mint prize vault shares to simulate supply going up without a deposit
        vm.startPrank(address(vault));
        twabController.mint(address(this), 1e9);
        vm.stopPrank();
        assertEq(vault.availableYieldBalance(), 0);
    }

    function testAvailableYieldBalance_tracksAssetsInPrizeVault() public {
        assertEq(vault.availableYieldBalance(), 0);

        uint256 yieldBuffer = vault.yieldBuffer();

        // mint directly to prize vault
        underlyingAsset.mint(address(vault), yieldBuffer + 3);
        assertEq(vault.availableYieldBalance(), 3);
    }

    /* ============ setLiquidationPair ============ */

    function testSetLiquidationPair() public {
        vm.expectEmit();
        emit LiquidationPairSet(address(vault), address(liquidationPair));

        vault.setLiquidationPair(address(liquidationPair));

        assertEq(vault.liquidationPair(), address(liquidationPair));
    }

    function testSetLiquidationPairNotZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.LPZeroAddress.selector));
        vault.setLiquidationPair(address(0));
    }

    function testSetLiquidationPairOnlyOwner() public {
        address _newLiquidationPair = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

        vm.startPrank(alice);

        vm.expectRevert(bytes("Ownable/caller-not-owner"));
        vault.setLiquidationPair(_newLiquidationPair);

        vm.stopPrank();
    }

    /* ============ isLiquidationPair ============ */

    function testIsLiquidationPair() public {
        address _newLiquidationPair = address(0xff3c527f9F5873bd735878F23Ff7eC5AB2E3b820);

        vault.setLiquidationPair(address(liquidationPair));
        assertEq(vault.isLiquidationPair(address(underlyingAsset), address(_newLiquidationPair)), false);
        assertEq(vault.isLiquidationPair(address(underlyingAsset), address(liquidationPair)), true);
        assertEq(vault.isLiquidationPair(address(1), address(liquidationPair)), false);

        vault.setLiquidationPair(_newLiquidationPair);
        assertEq(vault.isLiquidationPair(address(underlyingAsset), address(_newLiquidationPair)), true);
        assertEq(vault.isLiquidationPair(address(underlyingAsset), address(liquidationPair)), false);
        assertEq(vault.isLiquidationPair(address(1), address(_newLiquidationPair)), false);
    }

    /* ============ testSetYieldFeePercentage ============ */

    function testSetYieldFeePercentage() public {
        vm.expectEmit();
        emit YieldFeePercentageSet(YIELD_FEE_PERCENTAGE);

        vault.setYieldFeePercentage(YIELD_FEE_PERCENTAGE);
        assertEq(vault.yieldFeePercentage(), YIELD_FEE_PERCENTAGE);
    }

    function testSetYieldFeePercentageExceedsMax() public {
        uint32 max = vault.MAX_YIELD_FEE();

        vault.setYieldFeePercentage(max); // ok

        vm.expectRevert(
            abi.encodeWithSelector(PrizeVault.YieldFeePercentageExceedsMax.selector, max + 1, max)
        );
        vault.setYieldFeePercentage(max + 1); // not ok
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

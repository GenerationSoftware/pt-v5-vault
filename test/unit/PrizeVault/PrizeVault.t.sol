// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UnitBaseSetup, PrizePool, TwabController, ERC20, IERC20, IERC4626 } from "./UnitBaseSetup.t.sol";
import { IVaultHooks, VaultHooks } from "../../../src/interfaces/IVaultHooks.sol";
import { ERC20BrokenDecimalMock } from "../../contracts/mock/ERC20BrokenDecimalMock.sol";

import "../../../src/PrizeVault.sol";

contract PrizeVaultTest is UnitBaseSetup {

    /* ============ errors ============ */

    error SameDelegateAlreadySet(address delegate);

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

    /* ============ tryGetAssetDecimals ============ */

    function testTryGetAssetDecimals() public {
        (bool success, uint8 decimals) = vault.tryGetAssetDecimals(IERC20(underlyingAsset));
        assertEq(success, true);
        assertEq(decimals, 18);
    }

    function testTryGetAssetDecimals_DecimalFail() public {
        IERC20 brokenDecimalToken = new ERC20BrokenDecimalMock();
        (bool success, uint8 decimals) = vault.tryGetAssetDecimals(brokenDecimalToken);
        assertEq(success, false);
        assertEq(decimals, 0);
    }

    /* ============ maxDeposit / maxMint ============ */

    function testMaxDeposit_SubtractsLatentBalance() public {
        uint256 yieldVaultMaxDeposit = 1e18;

        // no latent balance, so full amount available
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)), abi.encode(yieldVaultMaxDeposit));
        assertEq(vault.maxDeposit(address(this)), yieldVaultMaxDeposit);

        // 1/4 max is in latent balance, so 3/4 amount available
        underlyingAsset.mint(address(vault), yieldVaultMaxDeposit / 4);
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)), abi.encode(yieldVaultMaxDeposit));
        assertEq(vault.maxDeposit(address(this)), (3 * yieldVaultMaxDeposit) / 4); // latent balance lowers user's max deposit

        // latent balance is over the max deposit so no more assets can be deposited
        underlyingAsset.mint(address(vault), yieldVaultMaxDeposit);
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxDeposit.selector, address(vault)), abi.encode(yieldVaultMaxDeposit));
        assertEq(vault.maxDeposit(address(this)), 0); // no more deposits
    }

    function testMaxDeposit_LimitedByTwabSupplyLimit() public {
        assertEq(vault.maxDeposit(address(this)), type(uint96).max);

        // deposit a bunch of tokens
        uint256 deposited = (9 * uint256(type(uint96).max)) / 10;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        vault.deposit(deposited, address(this));

        // maxDeposit is now only 10% of total twab supply cap
        assertEq(vault.maxDeposit(address(this)), uint256(type(uint96).max) - deposited); // remaining deposit room
    }

    /* ============ maxWithdraw ============ */

    /// @dev all withdraw/redeem flows in prize vault go through the yield vault redeem, so the prize vault max must be limited appropriately
    function testMaxWithdraw_CappedByYieldVaultMaxRedeem() public {
        // deposit some tokens
        uint256 deposited = 3e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        vault.deposit(deposited, address(this));

        // can withdraw full amount
        assertEq(vault.maxWithdraw(address(this)), deposited);

        // check if maxWithdraw is limited by a mocked yieldVault maxRedeem converted to assets
        uint256 expectedMaxWithdraw = 1e18;
        uint256 yieldVaultMaxRedeem = yieldVault.previewWithdraw(expectedMaxWithdraw); // we use previewWithdraw to convert assets to shares rounding up
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)), abi.encode(yieldVaultMaxRedeem));
        assertEq(vault.maxWithdraw(address(this)), expectedMaxWithdraw);

        // check for 0 maxWithdraw
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)), abi.encode(0));
        assertEq(vault.maxWithdraw(address(this)), 0);
    }

    /* ============ maxRedeem ============ */

    /// @dev all withdraw/redeem flows in prize vault go through the yield vault redeem, so the prize vault max must be limited appropriately
    function testMaxRedeem_CappedByYieldVaultMaxRedeem() public {
        // deposit some tokens
        uint256 deposited = 3e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        vault.deposit(deposited, address(this));

        // can redeem full amount 1:1
        assertEq(vault.maxRedeem(address(this)), deposited);

        // check if maxRedeem is limited by a mocked yieldVault maxRedeem converted to assets
        uint256 expectedMaxPrizeVaultRedeem = 1e18;
        uint256 yieldVaultMaxRedeem = yieldVault.previewWithdraw(expectedMaxPrizeVaultRedeem); // we use previewWithdraw to convert assets to shares rounding up
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)), abi.encode(yieldVaultMaxRedeem));
        assertEq(vault.maxRedeem(address(this)), expectedMaxPrizeVaultRedeem);

        // check for 0 maxRedeem
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)), abi.encode(0));
        assertEq(vault.maxRedeem(address(this)), 0);
    }

    function testMaxRedeem_ReturnsProportionalSharesWhenLossy() public {
        // deposit some tokens
        uint256 deposited = 3e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        vault.deposit(deposited, address(this));

        // can redeem full amount 1:1
        assertEq(vault.maxRedeem(address(this)), deposited);

        // yield vault loses some funds
        underlyingAsset.burn(address(yieldVault), deposited / 2);

        // check for full maxRedeem
        assertEq(vault.maxRedeem(address(this)), deposited);
    }

    function testMaxRedeem_ReturnsProportionalSharesWhenLossy_YieldVaultWithdrawCapped() public {
        // deposit some tokens
        uint256 deposited = 4e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        vault.deposit(deposited, address(this));

        // can redeem full amount 1:1
        assertEq(vault.maxRedeem(address(this)), deposited);

        // yield vault loses some funds
        underlyingAsset.burn(address(yieldVault), 2e18);

        // yield vault caps redemptions at 1/2 of what's left, check for half redemption on vault
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(IERC4626.maxRedeem.selector, address(vault)), abi.encode(yieldVault.previewWithdraw(1e18)));
        assertEq(vault.maxRedeem(address(this)), deposited / 2);
    }

    /* ============ previewWithdraw ============ */

    function testPreviewWithdraw() public {
        // deposit some tokens
        uint256 deposited = 4e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        uint256 shares = vault.deposit(deposited, address(this));

        // 1:1
        assertEq(vault.previewWithdraw(deposited), shares);
    }

    function testPreviewWithdraw_Lossy() public {
        // deposit some tokens
        uint256 deposited = 4e18;
        underlyingAsset.mint(address(this), deposited);
        underlyingAsset.approve(address(vault), deposited);
        uint256 shares = vault.deposit(deposited, address(this));

        // 1:1
        assertEq(vault.previewWithdraw(deposited), shares);

        // yield vault loses half of the funds
        underlyingAsset.burn(address(yieldVault), 2e18);
        assertEq(vault.previewWithdraw(deposited / 2), shares);
    }

    function testPreviewWithdraw_ZeroTotalAssets() public {
        assertEq(vault.totalAssets(), 0);
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.ZeroTotalAssets.selector));
        vault.previewWithdraw(1);
    }

    /* ============ sponsor ============ */

    function testSponsor() public {
        // sponsor the vault
        uint256 assets = 4e18;
        underlyingAsset.mint(address(this), assets);
        underlyingAsset.approve(address(vault), assets);
        vm.expectEmit();
        emit Sponsor(address(this), assets, assets); // 1:1
        uint256 shares = vault.sponsor(assets);
        assertEq(shares, assets);
        assertEq(twabController.delegateOf(address(vault), address(this)), address(1));

        // sponsor again
        underlyingAsset.mint(address(this), assets);
        underlyingAsset.approve(address(vault), assets);
        vm.expectEmit();
        emit Sponsor(address(this), assets, assets); // 1:1
        shares = vault.sponsor(assets);
        assertEq(shares, assets);
        assertEq(twabController.delegateOf(address(vault), address(this)), address(1));
    }

    // tests if the TWAB sponsor call reverts
    function testSponsor_SameDelegateAlreadySet() public {
        uint256 assets = 4e18;
        underlyingAsset.mint(address(this), assets);
        underlyingAsset.approve(address(vault), assets);

        // spoof sponsor revert
        bytes memory err = abi.encodeWithSelector(SameDelegateAlreadySet.selector, address(this));
        vm.mockCallRevert(address(twabController), abi.encodeWithSelector(TwabController.sponsor.selector, address(this)), err);
        vm.expectRevert(err);
        vault.sponsor(assets);
    }

    /* ============ depositAndMint ============ */

    function testDepositAndMint_DepositZeroAssets() public {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.DepositZeroAssets.selector));
        vault.depositAndMint(alice, alice, 0, 1);
    }

    function testDepositAndMint_MintZeroShares() public {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.MintZeroShares.selector));
        vault.depositAndMint(alice, alice, 1, 0);
    }

    /* ============ burnAndWithdraw ============ */

    function testDepositAndMint_BurnZeroShares() public {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.BurnZeroShares.selector));
        vault.burnAndWithdraw(alice, alice, alice, 0, 1);
    }

    function testDepositAndMint_WithdrawZeroAssets() public {
        vm.expectRevert(abi.encodeWithSelector(PrizeVault.WithdrawZeroAssets.selector));
        vault.burnAndWithdraw(alice, alice, alice, 1, 0);
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

    /* ============ currentYieldBuffer ============ */

    function testAvailableYieldBuffer() public {
        assertEq(vault.currentYieldBuffer(), 0); // no yield

        uint256 yieldBuffer = vault.yieldBuffer();

        // 1 asset available in buffer
        underlyingAsset.mint(address(vault), 1);
        assertEq(vault.currentYieldBuffer(), 1);

        // full buffer
        underlyingAsset.mint(address(vault), yieldBuffer - 1);
        assertEq(vault.currentYieldBuffer(), yieldBuffer);

        // can't exceed full buffer
        underlyingAsset.mint(address(vault), 1e18);
        assertEq(vault.currentYieldBuffer(), yieldBuffer);

        // mint prize vault shares to simulate supply going up without a deposit
        vm.startPrank(address(vault));
        twabController.mint(address(this), uint96(1e18 + yieldBuffer));
        vm.stopPrank();
        assertEq(vault.currentYieldBuffer(), 0);
    }

    /* ============ totalYieldBalance ============ */

    function testTotalYieldBalance() public {
        uint256 yieldBuffer = vault.yieldBuffer();
        assertGt(yieldBuffer, 0);

        // 1 asset in yield
        underlyingAsset.mint(address(vault), 1);
        assertEq(vault.totalYieldBalance(), 1);

        // full buffer
        underlyingAsset.mint(address(vault), yieldBuffer - 1);
        assertEq(vault.totalYieldBalance(), yieldBuffer);

        // exceeds buffer
        underlyingAsset.mint(address(vault), 1e18);
        assertEq(vault.totalYieldBalance(), yieldBuffer + 1e18);

        // mint prize vault shares to simulate supply going up without a deposit
        vm.startPrank(address(vault));
        twabController.mint(address(this), uint96(1e18 + yieldBuffer));
        vm.stopPrank();
        assertEq(vault.totalYieldBalance(), 0);
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
        uint96 reward,
        address rewardRecipient
    ) public returns (uint256) {
        return vault.claimPrize(winner, tier, prizeIndex, reward, rewardRecipient);
    }

    /* ============ mocks ============ */

    function mockPrizePoolClaimPrize(
        uint8 _tier,
        address _winner,
        uint32 _prizeIndex,
        uint96 _reward,
        address _rewardRecipient
    ) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                PrizePool.claimPrize.selector,
                _winner,
                _tier,
                _prizeIndex,
                _winner,
                _reward,
                _rewardRecipient
            ),
            abi.encode(100)
        );
    }

    function mockPrizePoolClaimPrize(
        uint8 _tier,
        address _winner,
        uint32 _prizeIndex,
        address _recipient,
        uint96 _reward,
        address _rewardRecipient
    ) public {
        vm.mockCall(
            address(prizePool),
            abi.encodeWithSelector(
                PrizePool.claimPrize.selector,
                _winner,
                _tier,
                _prizeIndex,
                _recipient,
                _reward,
                _rewardRecipient
            ),
            abi.encode(100)
        );
    }
}

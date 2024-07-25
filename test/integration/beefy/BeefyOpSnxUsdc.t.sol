// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract BeefyOpSnxUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 123080680;
    uint256 forkBlockTimestamp = 1721760137;

    address internal _beefyWrapper = address(0x182be93E1C0C4d305fe43bD093292F21fd679797);

    address internal _asset = address(0x894d6Ea97767EbeCEfE01c9410f6Bd67935AA952);
    address internal _assetWhale = address(0xde4901634990888102A7A017f36c7bd2F1Dc2B1e);
    address internal _yieldVault;
    address internal _mooVault = address(0x6A058d02bfFBaf75d9a9bdF2AA3B0F691F7777D5);
    address internal _mooYieldSource = address(0xe9E82973983951388C9B334A56D4Df26971e4Cdd);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        // withdraw some assets from the moo vault so the whale balance is uncoupled from yield
        vm.startPrank(_assetWhale);
        (bool success2,) = _mooVault.call(abi.encodeWithSignature("withdrawAll()"));
        require(success2, "withdraw failed");
        vm.stopPrank();
        require(IERC20(_asset).balanceOf(_assetWhale) > 0, "zero whale balance");
        return (IERC20(_asset), 18, 60_000_000e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        (bool success, bytes memory data) = _beefyWrapper.call(abi.encodeWithSignature("clone(address)", _mooVault));
        require(success, "beefy vault wrapper failed");
        (_yieldVault) = abi.decode(data, (address));
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
        ignoreLoss = true; // loss would occur on the LP token, not the reward contract
    }

    function afterSetup() public virtual override { }

    /* ============ helpers to override ============ */

    /// @dev The max amount of assets than can be dealt.
    function maxDeal() public virtual override returns (uint256) {
        return underlyingAsset.balanceOf(_assetWhale);
    }

    /// @dev May revert if the amount requested exceeds the amount available to deal.
    function dealAssets(address to, uint256 amount) public virtual override prankception(_assetWhale) {
        underlyingAsset.transfer(to, amount);
    }

    /// @dev Accrues yield by letting time pass and triggering multiple yield accruals
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        // yield accrues on deposit / withdraw so we can do a deposit and withdraw to the yield vault directly to trigger some yield accrual
        uint256 amount = maxDeal() / 100; // some small amount of assets
        underlyingAsset.approve(_yieldVault, amount);
        yieldVault.deposit(amount, _assetWhale);
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
        uint256 maxRedeem = yieldVault.maxRedeem(_assetWhale);
        yieldVault.redeem(maxRedeem, _assetWhale, _assetWhale);

        // we also call a deposit directly on the moo vault to ensure it triggers a yield accrual
        underlyingAsset.approve(_mooVault, amount);
        (bool success,) = _mooVault.call(abi.encodeWithSignature("deposit(uint256)", amount));
        assertEq(success, true, "moo vault deposit success");
    }

    function _simulateLoss() internal virtual override {
        
    }

}
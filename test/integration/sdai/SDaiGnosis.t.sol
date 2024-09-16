// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract SDaiGnosisIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 36035810;
    uint256 forkBlockTimestamp = 1726517410;

    address internal _asset = address(0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d);
    address internal _assetWhale = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address internal _yieldVault = address(0xaf204776c7245bF4147c2612BF6e5972Ee483701);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("gnosis"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 1 gwei;
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

    /// @dev Accrues yield when dripped wxDAI
    function _accrueYield() internal virtual override {
        dealAssets(address(yieldVault), 1000e18);
    }

    /// @dev Since it's difficult to simulate any loss in the DSR system, we'll simulate loss by removing sDAI from the prize vault
    function _simulateLoss() internal virtual override prankception(address(prizeVault)) {
        yieldVault.transfer(_assetWhale, yieldVault.balanceOf(address(prizeVault)) / 2);
    }

}
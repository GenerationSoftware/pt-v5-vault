// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MoonwellWETHBaseIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 14196582;
    uint256 forkBlockTimestamp = 1715182511;

    address internal _asset = address(0x4200000000000000000000000000000000000006);
    address internal _assetWhale = address(0xcDAC0d6c6C59727a65F871236188350531885C43);
    address internal _yieldVault = address(0x41D7dDF285A08C74A4cB9FDc979C703B10c30ab1);
    address internal _mAsset = address(0x628ff693426583D9a7FB391E54366292F509D457);
    address internal _mAssetWhale = address(0x9e67663C01e86C7bd8C3cd2285c681Dbad1C8327);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3300e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("base"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
        assetPrecisionLoss = 9; // loses 9 decimals of precision due to lossy conversion rate
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

    /// @dev Accrues yield by sending assets to the yield vault
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        IERC20(_asset).transfer(_yieldVault, 1e16);
        _mAsset.call("accrueInterest()");
        vm.warp(block.timestamp + 1 days);
        _mAsset.call("accrueInterest()");
    }

    /// @dev Simulates loss by transferring some mAsset tokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_mAsset).transfer(_mAssetWhale, IERC20(_mAsset).balanceOf(_yieldVault) / 2);
    }

}
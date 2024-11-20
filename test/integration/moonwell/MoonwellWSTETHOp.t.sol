// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MoonwellWSTETHOpIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 128232003;
    uint256 forkBlockTimestamp = 1732105983;

    address internal _asset = address(0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb);
    address internal _assetWhale = address(0xc45A479877e1e9Dfe9FcD4056c699575a1045dAA);
    address internal _yieldVault = address(0x8878179406f7EB7317326233e5b17b8a42B7170E);
    address internal _mAsset = address(0xbb3b1aB66eFB43B10923b87460c0106643B83f9d);
    address internal _mAssetWhale = address(0xb497070466Dc15FA6420b4781bB0352257146495);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3300e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
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
        return underlyingAsset.balanceOf(_assetWhale) / 100;
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
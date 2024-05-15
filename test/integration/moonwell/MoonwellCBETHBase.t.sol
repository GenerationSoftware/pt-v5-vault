// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract MoonwellCBETHBaseIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 14503375;
    uint256 forkBlockTimestamp = 1715796097;

    address internal _asset = address(0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22);
    address internal _assetWhale = address(0x47cA96Ea59C13F72745928887f84C9F52C3D7348);
    address internal _yieldVault = address(0x71B271952c3335e7258fBdCAE5CD3a57E76b5b51);
    address internal _mAsset = address(0x3bf93770f2d4a794c3d9EBEfBAeBAE2a8f09A5E5);
    address internal _mAssetWhale = address(0x2107dC09Fd3C7127749C1A47C84E4A33D6e72F1A);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3100e18);
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
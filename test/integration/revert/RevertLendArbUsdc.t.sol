// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract RevertLendArbUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 327797940;
    uint256 forkBlockTimestamp = 1745015074;

    address internal _asset = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address internal _assetWhale = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address internal _yieldVault = address(0x74E6AFeF5705BEb126C6d3Bf46f8fad8F3e07825);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("arbitrum"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.5 gwei;
        ignoreLoss = true; // No obvious way to simulate loss
        // assetPrecisionLoss = 1; // loses 1 decimal of precision due to extra 1-wei rounding errors on transfer
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

    /// @dev Accrues yield by letting time pass
    function _accrueYield() internal virtual override {
        vm.warp(block.timestamp + 1 days);
    }

    function _simulateLoss() internal virtual override prankception(_yieldVault) {
       
    }

}
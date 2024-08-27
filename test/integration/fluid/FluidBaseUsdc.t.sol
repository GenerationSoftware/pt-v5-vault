// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract FluidBaseUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 18993698;
    uint256 forkBlockTimestamp = 1724776743;

    address internal _asset = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address internal _assetWhale = address(0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3);
    address internal _yieldVault = address(0xf42f5795D9ac7e9D757dB633D693cD548Cfd9169);
    address internal _fluidLiquidityProxy = address(0x52Aa899454998Be5b000Ad077a46Bbe360F4e497);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
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
        ignoreLoss = true; // unsure how to trigger loss on the market
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
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        vm.warp(block.timestamp + 1 days);
    }

    /// @dev 
    function _simulateLoss() internal virtual override {
        
    }

}
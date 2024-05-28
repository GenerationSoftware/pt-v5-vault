// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract GearboxArbWethV3IntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 215943912;
    uint256 forkBlockTimestamp = 1716909490;

    address internal _asset = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address internal _assetWhale = address(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
    address internal _yieldVault = address(0x04419d3509f13054f60d253E0c79491d9E683399);

    address internal _creditAccount = address(0xA350A0BfbAfEcd5411E12545775264B43098bEB2);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 3300e18);
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
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
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
        vm.warp(block.timestamp + 2 days);
    }

    /// @dev Simulates loss by transferring some latent WETH out of a credit account
    function _simulateLoss() internal virtual override prankception(_creditAccount) {
        uint256 wethBalance = IERC20(_asset).balanceOf(_creditAccount);
        IERC20(_asset).transfer(_assetWhale, wethBalance / 2);
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YieldDaddyAaveArbUsdcIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 215943912;
    uint256 forkBlockTimestamp = 1716909490;

    address internal _asset = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address internal _assetWhale = address(0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7);
    address internal _aToken = address(0x724dc807b04555b71ed48a6896b6F41593b8C637);
    address internal _aTokenWhale = address(0x50288c30c37FA1Ec6167a31E575EA8632645dE20);
    address internal _yieldVault = address(0x85870b56E2C96e444ab29DEC3A7c13f1F05c2B01);

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

    /// @dev Accrues yield by sending aTokens to the yield vault as well as letting some time pass
    function _accrueYield() internal virtual override prankception(_aTokenWhale) {
        IERC20(_aToken).transfer(_yieldVault, 10 ** assetDecimals);
        vm.warp(block.timestamp + 1 days);
    }

    /// @dev Simulates loss by transferring some liquid aTokens out of the yield vault
    function _simulateLoss() internal virtual override prankception(_yieldVault) {
        IERC20(_aToken).transfer(_aTokenWhale, IERC20(_aToken).balanceOf(_yieldVault) / 2); // transfer aTokens out of the yield vault
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YieldDaddyAaveArbWethIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 215943912;
    uint256 forkBlockTimestamp = 1716909490;

    address internal _asset = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address internal _assetWhale = address(0x70d95587d40A2caf56bd97485aB3Eec10Bee6336);
    address internal _aToken = address(0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8);
    address internal _aTokenWhale = address(0xF715724abba480D4D45f4cb52BEF5ce5E3513CCC);
    address internal _yieldVault = address(0xa8426922461E7D6B0B94A0819642b5c9333cE0C6);

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
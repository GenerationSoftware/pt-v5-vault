// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract YieldDaddyAaveOpUsdcTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 116368447;
    uint256 forkBlockTimestamp = 1708335672;

    address internal _asset = address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    address internal _assetWhale = address(0xf89d7b9c864f589bbF53a82105107622B35EaA40);
    address internal _aToken = address(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5);
    address internal _aTokenWhale = address(0x66627C3bF54b9aCDA8409032CaF7b966d101fead);
    address internal _yieldVault = address(0x7624E0a373b8c77B07E5d5242fD7a194ecC9A4C6);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
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
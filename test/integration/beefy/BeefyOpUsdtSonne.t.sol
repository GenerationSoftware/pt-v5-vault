// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract BeefyOpUsdtSonneTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 116368447;
    uint256 forkBlockTimestamp = 1708335672;

    address internal _asset = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    address internal _assetWhale = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    address internal _yieldVault = address(0xEA05aa0dfCfdE7aD40F9E2Cb85d162d18498Bf9A);
    address internal _mooVault = address(0x6f09487B60108c14fAE003531C431eEB326Db0ec);
    address internal _mooYieldSource = address(0xeB4bb4815D2DE1891C3D84a16AE20634604E3308);
    address internal _sonneYieldToken = address(0x5Ff29E4470799b982408130EFAaBdeeAE7f66a10);

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

    /// @dev Accrues yield by letting time pass and triggering multiple yield accruals
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        // yield accrues on deposit / withdraw so we can do a deposit and withdraw to the yield vault directly to trigger some yield accrual
        uint256 amount = 10 ** assetDecimals; // some small amount of assets
        underlyingAsset.approve(_yieldVault, amount);
        yieldVault.deposit(amount, _assetWhale);
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
        uint256 maxRedeem = yieldVault.maxRedeem(_assetWhale);
        yieldVault.redeem(maxRedeem, _assetWhale, _assetWhale);

        // we also call a deposit directly on the moo vault to ensure it triggers a yield accrual
        underlyingAsset.approve(_mooVault, amount);
        (bool success,) = _mooVault.call(abi.encodeWithSignature("deposit(uint256)", amount));
        assertEq(success, true, "moo vault deposit success");
    }

    /// @dev Simulates loss by sending yield-bearing tokens out of the yield source and re-depositing some assets to trigger an update
    function _simulateLoss() internal virtual override prankception(_mooYieldSource) {
        IERC20(_sonneYieldToken).transfer(_assetWhale, IERC20(_sonneYieldToken).balanceOf(_mooYieldSource) / 2);
        startPrank(alice);
        uint256 amount = 10 ** assetDecimals;
        dealAssets(alice, amount);
        underlyingAsset.approve(_yieldVault, amount);
        yieldVault.deposit(amount, alice);
        stopPrank();
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract BeefyBaseUsdcCompV3IntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 14586797;
    uint256 forkBlockTimestamp = 1715962966;

    address internal _beefyWrapper = address(0x917447f8f52E7Db26cE7f52BE2F3fcb4d4D00832);

    address internal _asset = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    address internal _assetWhale = address(0xd5c41FD4a31Eaaf5559FfCC60Ec051fcB8eCC375);
    address internal _yieldVault;
    address internal _mooVault = address(0xeF6ED674486E54507d0f711C0d388BD8a1552E6F);
    address internal _mooYieldSource = address(0x2b4eF83aeE6bb3Dd5253dAa7d0756Ef5bD95f40f);
    address internal _compUsdc = address(0xb125E6687d4313864e53df431d5425969c15Eb2F);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 6, 1e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        (bool success, bytes memory data) = _beefyWrapper.call(abi.encodeWithSignature("clone(address)", _mooVault));
        require(success, "beefy vault wrapper failed");
        (_yieldVault) = abi.decode(data, (address));
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("base"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        assetPrecisionLoss = 1; // rounding errors exceed 1 wei, so a slightly larger yield buffer should be used for consistency
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

    /// @dev Accrues yield by depositing and letting time pass
    function _accrueYield() internal virtual override prankception(_assetWhale) {
        // yield accrues on deposit / withdraw so we can do a deposit and withdraw to the yield vault directly to trigger some yield accrual
        uint256 amount = 10 ** assetDecimals; // some small amount of assets
        underlyingAsset.approve(_yieldVault, amount);
        yieldVault.deposit(amount, _assetWhale);
        vm.warp(block.timestamp + 1 days); // let 1 day pass by
        uint256 maxRedeem = yieldVault.maxRedeem(_assetWhale);
        yieldVault.redeem(maxRedeem, _assetWhale, _assetWhale);
    }

    /// @dev Simulates loss by sending yield-bearing tokens out of the yield source and re-depositing some assets to trigger an update
    function _simulateLoss() internal virtual override prankception(_mooYieldSource) {
        IERC20(_compUsdc).transfer(_assetWhale, IERC20(_compUsdc).balanceOf(_mooYieldSource) / 2);
        startPrank(alice);
        uint256 amount = 10 ** assetDecimals;
        dealAssets(alice, amount);
        underlyingAsset.approve(_yieldVault, amount);
        yieldVault.deposit(amount, alice);
        stopPrank();
    }

}
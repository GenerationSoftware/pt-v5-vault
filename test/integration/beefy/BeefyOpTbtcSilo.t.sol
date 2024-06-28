// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";

contract BeefyOpTbtcSiloIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 121615714;
    uint256 forkBlockTimestamp = 1718830205;

    address internal _beefyWrapper = address(0x182be93E1C0C4d305fe43bD093292F21fd679797);

    address internal _asset = address(0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40);
    address internal _assetWhale = address(0x1Dc5c0f8668a9F54ED922171d578011850ca0341);
    address internal _yieldVault;
    address internal _mooVault = address(0xB54f0b4E02f2d98eD29FbFDC9D2BB5Fd02a5cb12);
    address internal _mooYieldSource = address(0x1A76c5025d00bCfe0D38d1b223560E795F793Cfb);
    address internal _siloYieldToken = address(0x767C9ab86670A15bBe1af725bF052F4c1c1C4aE9);
    address internal _siloYieldTokenWhale = address(0x658E0F8A4644719944655b59201bc0C77af9c002);

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(_asset), 18, 64000e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        (bool success, bytes memory data) = _beefyWrapper.call(abi.encodeWithSignature("clone(address)", _mooVault));
        require(success, "beefy vault wrapper failed");
        (_yieldVault) = abi.decode(data, (address));
        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
        assetPrecisionLoss = 1; // extra wei rounding errors
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

    /// @dev Accrues yield by sending silo tokens to the strategy
    function _accrueYield() internal virtual override prankception(_siloYieldTokenWhale) {
        // yield accrues on deposit / withdraw so we can do a deposit and withdraw to the yield vault directly to trigger some yield accrual
        // uint256 amount = 10 ** assetDecimals; // some small amount of assets
        // underlyingAsset.approve(_yieldVault, amount);
        // yieldVault.deposit(amount, _assetWhale);
        // vm.warp(block.timestamp + 1 days); // let 1 day pass by
        // uint256 maxRedeem = yieldVault.maxRedeem(_assetWhale);
        // yieldVault.redeem(maxRedeem, _assetWhale, _assetWhale);

        // // we also call a deposit directly on the moo vault to ensure it triggers a yield accrual
        // underlyingAsset.approve(_mooVault, amount);
        // (bool success,) = _mooVault.call(abi.encodeWithSignature("deposit(uint256)", amount));
        // assertEq(success, true, "moo vault deposit success");

        IERC20(_siloYieldToken).transfer(_mooYieldSource, IERC20(_siloYieldToken).balanceOf(_siloYieldTokenWhale) / 2);
    }

    /// @dev Simulates loss by sending yield-bearing tokens out of the yield source and re-depositing some assets to trigger an update
    function _simulateLoss() internal virtual override prankception(_mooYieldSource) {
        IERC20(_siloYieldToken).transfer(_assetWhale, IERC20(_siloYieldToken).balanceOf(_mooYieldSource) / 2);
        // startPrank(alice);
        // uint256 amount = 10 ** assetDecimals;
        // dealAssets(alice, amount);
        // underlyingAsset.approve(_yieldVault, amount);
        // yieldVault.deposit(amount, alice);
        // stopPrank();
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseIntegration, IERC20, IERC4626 } from "../BaseIntegration.t.sol";
import { WRETH, IERC20 as RETH_IERC20 } from "rETHERC4626/WRETH.sol";

interface Oracle {
    function rate() external returns (uint256);
    function updateRate(uint256) external;
}

contract wrETHOptimismDeployedIntegrationTest is BaseIntegration {
    uint256 fork;
    uint256 forkBlock = 123126239;
    uint256 forkBlockTimestamp = 1721851255;

    address internal _reth = address(0x9Bcef72be871e61ED4fBbc7630889beE758eb81D);
    address internal _rethWhale = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address internal _wrethWhale;
    address internal _l1Owner = address(0xDDDcf2C25D50ec22E67218e873D46938650d03a7);
    address internal _crossDomainMessenger = address(0x4200000000000000000000000000000000000007);
    Oracle internal _oracle = Oracle(address(0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F));
    address internal _yieldVault = address(0xA73ec45Fe405B5BFCdC0bF4cbc9014Bb32a01cd2);

    WRETH internal _wreth = WRETH(address(0x67CdE7AF920682A29fcfea1A179ef0f30F48Df3e));

    /* ============ setup ============ */

    function setUpUnderlyingAsset() public virtual override returns (IERC20 asset, uint8 decimals, uint256 approxAssetUsdExchangeRate) {
        return (IERC20(address(_wreth)), 18, 3.4e18);
    }

    function setUpYieldVault() public virtual override returns (IERC4626) {
        _wrethWhale = makeAddr("wrethWhale");
        vm.startPrank(_rethWhale);
        IERC20(_reth).approve(address(_wreth), type(uint256).max);
        _wreth.mint(IERC20(_reth).balanceOf(_rethWhale));
        _wreth.transfer(_wrethWhale, _wreth.balanceOf(_rethWhale));
        require(_wreth.balanceOf(_wrethWhale) > 0, "no wreth balance");
        vm.stopPrank();

        return IERC4626(_yieldVault);
    }

    function setUpFork() public virtual override {
        fork = vm.createFork(vm.rpcUrl("optimism"), forkBlock);
        vm.selectFork(fork);
        vm.warp(forkBlockTimestamp);
    }

    function beforeSetup() public virtual override {
        lowGasPriceEstimate = 0.05 gwei; // just L2 gas, we ignore L1 costs for a super low estimate
        roundingErrorOnTransfer = 1; // 1 wei rounding error on transfer is common with wrETH
    }

    function afterSetup() public virtual override { }

    /* ============ helpers to override ============ */

    /// @dev The max amount of assets than can be dealt.
    function maxDeal() public virtual override returns (uint256) {
        return _wreth.balanceOf(_wrethWhale);
    }

    /// @dev May revert if the amount requested exceeds the amount available to deal.
    function dealAssets(address to, uint256 amount) public virtual override prankception(_wrethWhale) {
        _wreth.transfer(to, amount);
    }

    /// @dev Accrues yield by increasing the oracle price
    function _accrueYield() internal virtual override prankception(_crossDomainMessenger) {
        uint256 _rate = _oracle.rate();
        vm.mockCall(_crossDomainMessenger, abi.encodeWithSignature("xDomainMessageSender()"), abi.encode(_l1Owner));
        _oracle.updateRate((_rate * (1e18 + (uint256(0.03e18) / 365))) / 1e18); // approx daily rate increase for 3% APR 
        _wreth.rebase();
    }

    /// @dev Simulates loss by decreasing the oracle price
    function _simulateLoss() internal virtual override prankception(_crossDomainMessenger) {
        uint256 _rate = _oracle.rate();
        vm.mockCall(_crossDomainMessenger, abi.encodeWithSignature("xDomainMessageSender()"), abi.encode(_l1Owner));
        _oracle.updateRate(_rate / 2);
        _wreth.rebase();
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC4626Test, IMockERC20 } from "erc4626-tests/ERC4626.test.sol";

import { PrizePool } from "pt-v5-prize-pool/PrizePool.sol";
import { TwabController } from "pt-v5-twab-controller/TwabController.sol";

import { PrizeVault } from "../../../src/PrizeVault.sol";

import { IERC4626, IERC20 } from "openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ERC20Mock } from "openzeppelin/mocks/ERC20Mock.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";

import { YieldVault } from "../../contracts/mock/YieldVault.sol";
import { PrizePoolMock } from "../../contracts/mock/PrizePoolMock.sol";

import { LiquidationPairMock } from "../../contracts/mock/LiquidationPairMock.sol";
import { LiquidationRouterMock } from "../../contracts/mock/LiquidationRouterMock.sol";

contract PrizeVaultERC4626AndLiquidationFuzzTest is ERC4626Test {

    TwabController public twabController;
    PrizePoolMock public prizePool;
    ERC20Mock public prizeToken;
    IERC4626 public yieldVault;

    LiquidationRouterMock public liquidationRouter;
    LiquidationPairMock public liquidationPair;
    PrizeVault public prizeVault;

    function setUp() public virtual override {
        _underlying_ = address(new ERC20Mock());

        twabController = new TwabController(1 days, uint32(block.timestamp));
        prizeToken = new ERC20Mock();
        prizePool = new PrizePoolMock(prizeToken, twabController);
        yieldVault = new YieldVault(
            _underlying_,
            "Mock Yield Vault",
            "MYV"
        );

        _vault_ = address(
            new PrizeVault(
                "PoolTogether Test Vault",
                "pTest",
                yieldVault,
                PrizePool(address(prizePool)),
                address(this),
                address(this),
                0,
                address(this)
            )
        );

        prizeVault = PrizeVault(address(_vault_));
        liquidationPair = new LiquidationPairMock(
            address(prizeVault),
            address(prizePool),
            address(prizeToken),
            address(_underlying_)
        );
        liquidationRouter = new LiquidationRouterMock();

        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = false;
    }

    /* ============ Override setup ============ */

    function setUpVault(Init memory init) public virtual override {
        for (uint256 i = 0; i < N; i++) {
            init.user[i] = makeAddr(Strings.toString(i));
            address user = init.user[i];

            vm.assume(_isEOA(user));

            uint256 shares = bound(init.share[i], 0, type(uint96).max);
            try IMockERC20(_underlying_).mint(user, shares) {} catch {
                vm.assume(false);
            }

            _approve(_underlying_, user, _vault_, shares);

            vm.prank(user);
            try IERC4626(_vault_).deposit(shares, user) {} catch {
                vm.assume(false);
            }

            uint256 assets = bound(init.asset[i], 0, type(uint256).max);
            try IMockERC20(_underlying_).mint(user, assets) {} catch {
                vm.assume(false);
            }
        }

        setUpYield(init);
    }

    // Mint yield to the YieldVault
    function setUpYield(Init memory init) public virtual override {
        if (init.yield >= 0) {
            // gain
            uint256 gain = uint256(init.yield);
            try IMockERC20(_underlying_).mint(address(yieldVault), gain) {} catch {
                vm.assume(false);
            }
        } else {
            // loss
            vm.assume(init.yield > type(int256).min); // avoid overflow in conversion
            uint256 loss = uint256(-1 * init.yield);
            try IMockERC20(_underlying_).burn(address(yieldVault), loss) {} catch {
                vm.assume(false);
            }
        }
    }

    function _max_deposit(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return bound(IERC20(_underlying_).balanceOf(from), 0, type(uint96).max);
    }

    function _max_mint(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return bound(vault_convertToShares(IERC20(_underlying_).balanceOf(from)), 0, type(uint96).max);
    }

    function _max_withdraw(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return vault_convertToAssets(IERC20(_vault_).balanceOf(from));
    }

    function _max_redeem(address from) internal virtual override returns (uint256) {
        if (_unlimitedAmount) return type(uint96).max;
        return IERC20(_vault_).balanceOf(from);
    }

    /* ============ liquidatableBalanceOf ============ */

    function propLiquidatableBalanceOf() public {
        uint256 liquidatableBalanceOf = _call_vault(
            abi.encodeWithSelector(PrizeVault.liquidatableBalanceOf.selector, _underlying_)
        );

        uint256 totalAssets = prizeVault.totalAssets();
        uint256 depositedAssets = prizeVault.totalSupply();

        if (totalAssets < depositedAssets) {
            assertEq(liquidatableBalanceOf, 0, "can't liquidate since assets are less than deposits");
        } else {
            assertApproxEqAbs(liquidatableBalanceOf, totalAssets - depositedAssets, _delta_, "yield");
        }
    }

    function test_liquidatableBalanceOf(Init memory init) public virtual {
        setUpVault(init);
        propLiquidatableBalanceOf();
    }

    /* ============ liquidate ============ */

    function propLiquidate(address caller) public {
        vm.startPrank(caller);

        uint256 yield = _call_vault(
            abi.encodeWithSelector(PrizeVault.liquidatableBalanceOf.selector, _underlying_)
        );

        // Skips test if no yield is liquidatable
        vm.assume(yield != 0);
        require(yield != 0);

        uint256 callerAssetBalanceBefore = IERC20(_underlying_).balanceOf(caller);
        uint256 vaultTotalAssetsBefore = prizeVault.totalAssets();

        (uint256 callerPrizeTokenBalanceBefore, uint256 prizeTokenContributed) = _liquidate(
            liquidationRouter,
            liquidationPair,
            prizeToken,
            yield,
            caller
        );

        assertApproxEqAbs(
            prizeToken.balanceOf(caller),
            callerPrizeTokenBalanceBefore - prizeTokenContributed,
            _delta_,
            "caller prizeToken balance"
        );

        assertApproxEqAbs(
            prizeToken.balanceOf(address(prizePool)),
            prizeTokenContributed,
            _delta_,
            "prizePool prizeToken balance"
        );

        assertApproxEqAbs(
            IERC20(_underlying_).balanceOf(caller),
            callerAssetBalanceBefore + yield,
            _delta_,
            "caller assets balance after liquidation"
        );

        assertApproxEqAbs(
            prizeVault.totalAssets(),
            vaultTotalAssetsBefore - yield,
            _delta_,
            "vault total assets after liquidation"
        );

        assertApproxEqAbs(
            prizeVault.liquidatableBalanceOf(_underlying_),
            0,
            _delta_,
            "vault liquidatable balance after liquidation"
        );

        vm.stopPrank();
    }

    function test_liquidate(Init memory init, uint256 assets) public virtual {
        init.yield = int256(bound(assets, 10e18, type(uint96).max));

        setUpVault(init);
        prizeVault.setLiquidationPair(address(liquidationPair));

        address caller = init.user[0];
        prizeToken.mint(caller, type(uint256).max);

        propLiquidate(caller);
    }

    /* ============ helpers ============ */

    function _liquidate(
        LiquidationRouterMock _liquidationRouter,
        LiquidationPairMock _liquidationPair,
        IERC20 _prizeToken,
        uint256 _yield,
        address _user
    ) internal returns (uint256 userPrizeTokenBalanceBeforeSwap, uint256 prizeTokenContributed) {
        prizeTokenContributed = _liquidationPair.computeExactAmountIn(_yield);
        userPrizeTokenBalanceBeforeSwap = _prizeToken.balanceOf(_user);

        _prizeToken.approve(address(_liquidationRouter), prizeTokenContributed);
        _liquidationRouter.swapExactAmountOut(_liquidationPair, _user, _yield, prizeTokenContributed);
    }
}
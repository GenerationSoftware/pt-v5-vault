// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../external/LiquidatorLib.sol";

// Note: Need to store the results from the library in a variable to be picked up by forge coverage
// See: https://github.com/foundry-rs/foundry/pull/3128#issuecomment-1241245086

contract MockLiquidatorLib {
    function computeExactAmountIn(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        uint256 _amountOutB
    ) public pure returns (uint256) {
        uint256 amountIn = LiquidatorLib.computeExactAmountIn(
            _reserveA,
            _reserveB,
            _amountInB,
            _amountOutB
        );
        return amountIn;
    }

    function computeExactAmountOut(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        uint256 _amountInA
    ) public pure returns (uint256) {
        uint256 amountOut = LiquidatorLib.computeExactAmountOut(
            _reserveA,
            _reserveB,
            _amountInB,
            _amountInA
        );
        return amountOut;
    }

    function virtualBuyback(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB
    ) public pure returns (uint128, uint128) {
        (uint128 reserveA, uint128 reserveB) = LiquidatorLib._virtualBuyback(
            _reserveA,
            _reserveB,
            _amountInB
        );
        return (reserveA, reserveB);
    }

    function virtualSwap(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        uint256 _amountOutB,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint128 _minK
    ) public pure returns (uint128, uint128) {
        (uint128 reserveA, uint128 reserveB) = LiquidatorLib._virtualSwap(
            _reserveA,
            _reserveB,
            _amountInB,
            _amountOutB,
            _swapMultiplier,
            _liquidityFraction,
            _minK
        );
        return (reserveA, reserveB);
    }

    function applyLiquidityFraction(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        UFixed32x4 _liquidityFraction,
        uint256 _mink
    ) public pure returns (uint256, uint256) {
        (uint128 reserveA, uint128 reserveB) = LiquidatorLib._applyLiquidityFraction(
            _reserveA,
            _reserveB,
            _amountInB,
            _liquidityFraction,
            _mink
        );
        return (reserveA, reserveB);
    }

    function swapExactAmountIn(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        uint256 _amountInA,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint128 _minK
    ) public pure returns (uint256, uint256, uint256) {
        (uint256 reserveA, uint256 reserveB, uint256 amountOut) = LiquidatorLib.swapExactAmountIn(
            _reserveA,
            _reserveB,
            _amountInB,
            _amountInA,
            _swapMultiplier,
            _liquidityFraction,
            _minK
        );
        return (reserveA, reserveB, amountOut);
    }

    function swapExactAmountOut(
        uint128 _reserveA,
        uint128 _reserveB,
        uint256 _amountInB,
        uint256 _amountOutB,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint128 _minK
    ) public pure returns (uint256, uint256, uint256) {
        (uint256 reserveA, uint256 reserveB, uint256 amountIn) = LiquidatorLib.swapExactAmountOut(
            _reserveA,
            _reserveB,
            _amountInB,
            _amountOutB,
            _swapMultiplier,
            _liquidityFraction,
            _minK
        );
        return (reserveA, reserveB, amountIn);
    }

    function getAmountOut(
        uint256 amountIn,
        uint128 virtualReserveIn,
        uint128 virtualReserveOut
    ) public pure returns (uint256) {
        uint256 amountOut = LiquidatorLib.getAmountOut(amountIn, virtualReserveIn, virtualReserveOut);
        return amountOut;
    }

    function getAmountIn(
        uint256 amountOut,
        uint128 virtualReserveIn,
        uint128 virtualReserveOut
    ) public pure returns (uint256) {
        uint256 amountIn = LiquidatorLib.getAmountIn(amountOut, virtualReserveIn, virtualReserveOut);
        return amountIn;
    }
}

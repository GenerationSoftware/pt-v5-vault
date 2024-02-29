// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

import "openzeppelin/token/ERC20/IERC20.sol";

import "./FixedMathLib.sol";

/**
 * @title  PoolTogether Liquidator Library
 * @author PoolTogether Inc. Team
 * @notice A library to perform swaps on a UniswapV2-like pair of tokens. Implements logic that
 *         manipulates the token reserve amounts on swap.
 * @dev    Each swap consists of four steps:
 *            1. A virtual buyback of the tokens available from the ILiquidationSource. This ensures
 *               that the value of the tokens available from the ILiquidationSource decays as
 *               tokens accrue.
 *            2. The main swap of tokens the user requested.
 *            3. A virtual swap that is a small multiplier applied to the users swap. This is to
 *               push the value of the tokens being swapped back up towards the market value.
 *            4. A scaling of the virtual reserves. This is to ensure that the virtual reserves
 *               are large enough such that the next swap will have a tailored impact on the virtual
 *               reserves.
 * @dev    Numbered suffixes are used to identify the underlying token used for the parameter.
 *         For example, `amountIn1` and `reserve1` are the same token where `amountIn0` is different.
 */
library LiquidatorLib {
    /**
     * @notice Computes the amount of tokens that will be received for a given amount of tokens sent.
     * @param amountIn1 The amount of token 1 being sent in
     * @param reserve1 The amount of token 1 in the reserves
     * @param reserve0 The amount of token 0 in the reserves
     * @return amountOut0 The amount of token 0 that will be received given the amount in of token 1
     */
    function getAmountOut(
        uint256 amountIn1,
        uint128 reserve1,
        uint128 reserve0
    ) internal pure returns (uint256 amountOut0) {
        require(reserve0 > 0 && reserve1 > 0, "LiquidatorLib/insufficient-reserve-liquidity-a");
        uint256 numerator = amountIn1 * reserve0;
        uint256 denominator = amountIn1 + reserve1;
        amountOut0 = numerator / denominator;
        return amountOut0;
    }

    /**
     * @notice Computes the amount of tokens required to be sent in to receive a given amount of
     *                    tokens.
     * @param amountOut0 The amount of token 0 to receive
     * @param reserve1 The amount of token 1 in the reserves
     * @param reserve0 The amount of token 0 in the reserves
     * @return amountIn1 The amount of token 1 needed to receive the given amount out of token 0
     */
    function getAmountIn(
        uint256 amountOut0,
        uint128 reserve1,
        uint128 reserve0
    ) internal pure returns (uint256 amountIn1) {
        require(amountOut0 < reserve0, "LiquidatorLib/insufficient-reserve-liquidity-c");
        require(reserve0 > 0 && reserve1 > 0, "LiquidatorLib/insufficient-reserve-liquidity-d");
        uint256 numerator = amountOut0 * reserve1;
        uint256 denominator = uint256(reserve0) - amountOut0;
        amountIn1 = (numerator / denominator) + 1;
    }

    /**
     * @notice Performs a swap of all of the available tokens from the ILiquidationSource which
     *                    impacts the virtual reserves resulting in price decay as tokens accrue.
     * @param _reserve0 The amount of token 0 in the reserve
     * @param _reserve1 The amount of token 1 in the reserve
     * @param _amountIn1 The amount of token 1 to buy back
     * @return reserve0 The new amount of token 0 in the reserves
     * @return reserve1 The new amount of token 1 in the reserves
     */
    function _virtualBuyback(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1
    ) internal pure returns (uint128 reserve0, uint128 reserve1) {
        uint256 amountOut0 = getAmountOut(_amountIn1, _reserve1, _reserve0);
        reserve0 = _reserve0 - uint128(amountOut0);
        reserve1 = _reserve1 + uint128(_amountIn1);
    }

    /**
     * @notice Amplifies the users swap by a multiplier and then scales reserves to a configured ratio.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 to swap in
     * @param _amountOut1 The amount of token 1 to swap out
     * @param _swapMultiplier The multiplier to apply to the swap
     * @param _liquidityFraction The fraction relative to the amount of token 1 to scale the reserves to
     * @param _minK The minimum value of K to ensure that the reserves are not scaled too small
     * @return reserve0 The new amount of token 0 in the reserves
     * @return reserve1 The new amount of token 1 in the reserves
     */
    function _virtualSwap(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        uint256 _amountOut1,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint256 _minK
    ) internal pure returns (uint128 reserve0, uint128 reserve1) {
        uint256 virtualAmountOut1 = FixedMathLib.mul(_amountOut1, _swapMultiplier);

        uint256 virtualAmountIn0 = 0;
        if (virtualAmountOut1 < _reserve1) {
            // Sufficient reserves to handle the multiplier on the swap
            virtualAmountIn0 = getAmountIn(virtualAmountOut1, _reserve0, _reserve1);
        } else if (virtualAmountOut1 > 0 && _reserve1 > 1) {
            // Insuffucuent reserves in so cap it to max amount
            virtualAmountOut1 = _reserve1 - 1;
            virtualAmountIn0 = getAmountIn(virtualAmountOut1, _reserve0, _reserve1);
        } else {
            // Insufficient reserves
            // _reserve1 is 1, virtualAmountOut1 is 0
            virtualAmountOut1 = 0;
        }

        reserve0 = _reserve0 + uint128(virtualAmountIn0);
        reserve1 = _reserve1 - uint128(virtualAmountOut1);

        (reserve0, reserve1) = _applyLiquidityFraction(
            reserve0,
            reserve1,
            _amountIn1,
            _liquidityFraction,
            _minK
        );
    }

    /**
     * @notice Scales the reserves to a configured ratio.
     * @dev This is to ensure that the virtual reserves are large enough such that the next swap will
     *            have a tailored impact on the virtual reserves.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 swapped in
     * @param _liquidityFraction The fraction relative to the amount in of token 1 to scale the
     *                                                        reserves to
     * @param _minK The minimum value of K to validate the scaled reserves against
     * @return reserve0 The new amount of token 0 in the reserves
     * @return reserve1 The new amount of token 1 in the reserves
     */
    function _applyLiquidityFraction(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        UFixed32x4 _liquidityFraction,
        uint256 _minK
    ) internal pure returns (uint128 reserve0, uint128 reserve1) {
        uint256 reserve0_1 = (uint256(_reserve0) * _amountIn1 * FixedMathLib.multiplier) /
            (uint256(_reserve1) * UFixed32x4.unwrap(_liquidityFraction));
        uint256 reserve1_1 = FixedMathLib.div(_amountIn1, _liquidityFraction);

        // Ensure we can fit K into a uint256
        // Ensure new virtual reserves fit into uint96
        if (
            reserve0_1 <= type(uint96).max &&
            reserve1_1 <= type(uint96).max &&
            uint256(reserve1_1) * reserve0_1 > _minK
        ) {
            reserve0 = uint128(reserve0_1);
            reserve1 = uint128(reserve1_1);
        } else {
            reserve0 = _reserve0;
            reserve1 = _reserve1;
        }
    }

    /**
     * @notice Computes the amount of token 1 to swap in to get the provided amount of token 1 out.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 coming in
     * @param _amountOut1 The amount of token 1 to swap out
     * @return The amount of token 0 to swap in to receive the given amount out of token 1
     */
    function computeExactAmountIn(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        uint256 _amountOut1
    ) internal pure returns (uint256) {
        require(_amountOut1 <= _amountIn1, "LiquidatorLib/insufficient-balance-liquidity-a");
        (uint128 reserve0, uint128 reserve1) = _virtualBuyback(_reserve0, _reserve1, _amountIn1);
        return getAmountIn(_amountOut1, reserve0, reserve1);
    }

    /**
     * @notice Computes the amount of token 1 to swap out to get the procided amount of token 1 in.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 coming in
     * @param _amountIn0 The amount of token 0 to swap in
     * @return The amount of token 1 to swap out to receive the given amount in of token 0
     */
    function computeExactAmountOut(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        uint256 _amountIn0
    ) internal pure returns (uint256) {
        (uint128 reserve0, uint128 reserve1) = _virtualBuyback(_reserve0, _reserve1, _amountIn1);
        uint256 amountOut1 = getAmountOut(_amountIn0, reserve0, reserve1);
        require(amountOut1 <= _amountIn1, "LiquidatorLib/insufficient-balance-liquidity-b");
        return amountOut1;
    }

    /**
     * @notice Adjusts the provided reserves based on the amount of token 1 coming in and performs
     *                    a swap with the provided amount of token 0 in for token 1 out. Finally, scales the
     *                    reserves using the provided liquidity fraction, token 1 coming in and minimum k.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 coming in
     * @param _amountIn0 The amount of token 0 to swap in to receive token 1 out
     * @param _swapMultiplier The multiplier to apply to the swap
     * @param _liquidityFraction The fraction relative to the amount in of token 1 to scale the
     *                                                     reserves to
     * @param _minK The minimum value of K to validate the scaled reserves against
     * @return reserve0 The new amount of token 0 in the reserves
     * @return reserve1 The new amount of token 1 in the reserves
     * @return amountOut1 The amount of token 1 swapped out
     */
    function swapExactAmountIn(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        uint256 _amountIn0,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint256 _minK
    ) internal pure returns (uint128 reserve0, uint128 reserve1, uint256 amountOut1) {
        (reserve0, reserve1) = _virtualBuyback(_reserve0, _reserve1, _amountIn1);

        amountOut1 = getAmountOut(_amountIn0, reserve0, reserve1);
        require(amountOut1 <= _amountIn1, "LiquidatorLib/insufficient-balance-liquidity-c");
        reserve0 = reserve0 + uint128(_amountIn0);
        reserve1 = reserve1 - uint128(amountOut1);

        (reserve0, reserve1) = _virtualSwap(
            reserve0,
            reserve1,
            _amountIn1,
            amountOut1,
            _swapMultiplier,
            _liquidityFraction,
            _minK
        );
    }

    /**
     * @notice Adjusts the provided reserves based on the amount of token 1 coming in and performs
     *                 a swap with the provided amount of token 1 out for token 0 in. Finally, scales the
     *                reserves using the provided liquidity fraction, token 1 coming in and minimum k.
     * @param _reserve0 The amount of token 0 in the reserves
     * @param _reserve1 The amount of token 1 in the reserves
     * @param _amountIn1 The amount of token 1 coming in
     * @param _amountOut1 The amount of token 1 to swap out to receive token 0 in
     * @param _swapMultiplier The multiplier to apply to the swap
     * @param _liquidityFraction The fraction relative to the amount in of token 1 to scale the
     *                                                    reserves to
     * @param _minK The minimum value of K to validate the scaled reserves against
     * @return reserve0 The new amount of token 0 in the reserves
     * @return reserve1 The new amount of token 1 in the reserves
     * @return amountIn0 The amount of token 0 swapped in
     */
    function swapExactAmountOut(
        uint128 _reserve0,
        uint128 _reserve1,
        uint256 _amountIn1,
        uint256 _amountOut1,
        UFixed32x4 _swapMultiplier,
        UFixed32x4 _liquidityFraction,
        uint256 _minK
    ) internal pure returns (uint128 reserve0, uint128 reserve1, uint256 amountIn0) {
        require(_amountOut1 <= _amountIn1, "LiquidatorLib/insufficient-balance-liquidity-d");
        (reserve0, reserve1) = _virtualBuyback(_reserve0, _reserve1, _amountIn1);

        // do swap
        amountIn0 = getAmountIn(_amountOut1, reserve0, reserve1);
        reserve0 = reserve0 + uint128(amountIn0);
        reserve1 = reserve1 - uint128(_amountOut1);

        (reserve0, reserve1) = _virtualSwap(
            reserve0,
            reserve1,
            _amountIn1,
            _amountOut1,
            _swapMultiplier,
            _liquidityFraction,
            _minK
        );
    }
}

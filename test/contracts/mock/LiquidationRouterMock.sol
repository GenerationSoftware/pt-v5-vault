// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { LiquidationPairMock } from "./LiquidationPairMock.sol";

contract LiquidationRouterMock {
    using SafeERC20 for IERC20;

    function swapExactAmountOut(
        LiquidationPairMock _liquidationPair,
        address _receiver,
        uint256 _amountOut,
        uint256 _amountInMax
    ) external returns (uint256) {
        IERC20(_liquidationPair.tokenIn()).safeTransferFrom(
            msg.sender,
            _liquidationPair.target(),
            _liquidationPair.computeExactAmountIn(_amountOut)
        );

        return _liquidationPair.swapExactAmountOut(_receiver, _amountOut, _amountInMax);
    }
}

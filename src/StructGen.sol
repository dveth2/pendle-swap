// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

import {IPendleRouter} from "./interfaces/IPendleRouter.sol";

abstract contract StructGen {
    // EmptySwap means no swap aggregator is involved
    IPendleRouter.SwapData public emptySwap;

    // EmptyLimit means no limit order is involved
    IPendleRouter.LimitOrderData public emptyLimitOrderData;

    // DefaultApprox means no off-chain preparation is involved, more gas consuming (~ 180k gas)
    IPendleRouter.ApproxParams public defaultApprox =
        IPendleRouter.ApproxParams(0, type(uint256).max, 0, 256, 1e14);

    /// @notice create a simple TokenInput struct without using any aggregators. For more info please refer to
    /// IPAllActionTypeV3.sol
    function createTokenInputStruct(
        address tokenIn,
        uint256 netTokenIn
    ) internal view returns (IPendleRouter.TokenInput memory) {
        return
            IPendleRouter.TokenInput({
                tokenIn: tokenIn,
                netTokenIn: netTokenIn,
                tokenMintSy: tokenIn,
                pendleSwap: address(0),
                swapData: emptySwap
            });
    }

    /// @notice create a simple TokenOutput struct without using any aggregators. For more info please refer to
    /// IPAllActionTypeV3.sol
    function createTokenOutputStruct(
        address tokenOut,
        uint256 minTokenOut
    ) internal view returns (IPendleRouter.TokenOutput memory) {
        return
            IPendleRouter.TokenOutput({
                tokenOut: tokenOut,
                minTokenOut: minTokenOut,
                tokenRedeemSy: tokenOut,
                pendleSwap: address(0),
                swapData: emptySwap
            });
    }
}

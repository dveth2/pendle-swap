// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

interface IPendleRouter {
    enum OrderType {
        SY_FOR_PT,
        PT_FOR_SY,
        SY_FOR_YT,
        YT_FOR_SY
    }

    enum SwapType {
        NONE,
        KYBERSWAP,
        ODOS,
        // ETH_WETH not used in Aggregator
        ETH_WETH,
        OKX,
        ONE_INCH,
        RESERVE_1,
        RESERVE_2,
        RESERVE_3,
        RESERVE_4,
        RESERVE_5
    }

    struct Order {
        uint256 salt;
        uint256 expiry;
        uint256 nonce;
        OrderType orderType;
        address token;
        address YT;
        address maker;
        address receiver;
        uint256 makingAmount;
        uint256 lnImpliedRate;
        uint256 failSafeRate;
        bytes permit;
    }

    struct FillOrderParams {
        Order order;
        bytes signature;
        uint256 makingAmount;
    }

    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
    }

    struct TokenInput {
        address tokenIn;
        uint256 netTokenIn;
        address tokenMintSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct TokenOutput {
        address tokenOut;
        uint256 minTokenOut;
        address tokenRedeemSy;
        address pendleSwap;
        SwapData swapData;
    }

    struct LimitOrderData {
        address limitRouter;
        uint256 epsSkipMarket;
        FillOrderParams[] normalFills;
        FillOrderParams[] flashFills;
        bytes optData;
    }

    struct SwapData {
        SwapType swapType;
        address extRouter;
        bytes extCalldata;
        bool needScale;
    }

    function swapExactYtForSy(
        address receiver,
        address market,
        uint256 exactYtIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee);

    function swapExactPtForSy(
        address receiver,
        address market,
        uint256 exactPtIn,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee);

    function swapExactSyForYt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minYtOut,
        ApproxParams calldata guessYtOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netYtOut, uint256 netSyFee);

    function swapExactSyForPt(
        address receiver,
        address market,
        uint256 exactSyIn,
        uint256 minPtOut,
        ApproxParams calldata guessPtOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netPtOut, uint256 netSyFee);

    function mintSyFromToken(
        address receiver,
        address SY,
        uint256 minSyOut,
        TokenInput calldata input
    ) external payable returns (uint256 netSyOut);

    function redeemSyToToken(
        address receiver,
        address SY,
        uint256 netSyIn,
        TokenOutput calldata output
    ) external returns (uint256 netTokenOut);

    function addLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netSyIn,
        uint256 minLpOut,
        ApproxParams calldata guessPtReceivedFromSy,
        LimitOrderData calldata limit
    ) external returns (uint256 netLpOut, uint256 netSyFee);

    function removeLiquiditySingleSy(
        address receiver,
        address market,
        uint256 netLpToRemove,
        uint256 minSyOut,
        LimitOrderData calldata limit
    ) external returns (uint256 netSyOut, uint256 netSyFee);
}

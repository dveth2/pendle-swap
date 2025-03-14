// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPendleRouter} from "./interfaces/IPendleRouter.sol";
import {StructGen} from "./StructGen.sol";
import "@pendle/core-v2/contracts/interfaces/IPMarket.sol";

/// @title PendleAssetManager
/// @notice Manages user positions via Pendle router and handles token conversions
/// @dev Inherits from StructGen for struct generation and Ownable for access control
contract PendleAssetManager is StructGen, Ownable {
    using SafeERC20 for IERC20;

    /// @notice Represents different token types in the Pendle ecosystem
    /// @param UNDERLYING The base token (e.g., USDC)
    /// @param SY Standardized Yield token
    /// @param PT Principal token
    /// @param YT Yield token
    /// @param LP LP token
    enum TokenType {
        UNDERLYING,
        SY,
        PT,
        YT,
        LP
    }

    /// @notice Stores information about a Pendle market
    /// @param UNDERLYING The underlying token address
    /// @param SY The Standardized Yield token address
    /// @param PT The Principal token address
    /// @param YT The Yield token address
    /// @param LP The LP token address
    struct MarketInfo {
        address UNDERLYING;
        address SY;
        address PT;
        address YT;
        address LP;
    }

    /// @notice Maps market addresses to their corresponding market information
    mapping(address => MarketInfo) public pendleMarkets;

    /// @notice Stores user position information
    /// @param tokenType The type of token deposited
    /// @param amount The amount of tokens deposited
    struct UserInfo {
        TokenType tokenType;
        uint256 amount;
    }

    /// @notice Maps user addresses and market addresses to their position information
    /// @dev user => market => UserInfo
    mapping(address => mapping(address => UserInfo)) public userInfos;

    /// @notice The address of the Pendle Router contract
    address public immutable pendleRouter;

    /// @notice Event emitted when a user deposits tokens
    event Deposited(
        address indexed user,
        address indexed market,
        TokenType tokenInType,
        uint256 amount
    );

    /// @notice Event emitted when a user withdraws tokens
    event Withdrew(
        address indexed user,
        address indexed market,
        TokenType tokenOutType,
        uint256 amount
    );

    /// @notice Event emitted when a user converts tokens
    event Converted(
        address indexed user,
        address indexed market,
        TokenType tokenInType,
        uint256 amountIn,
        TokenType tokenOutType,
        uint256 amountOut
    );

    /// @notice Error for when a user has already deposited in a market
    error USER_ALREDY_DEPOSITED(address user, address market);

    /// @notice Error for zero amount inputs
    error ZeroAmount();

    /// @notice Error for when a market is already registered
    error MARKET_ALREADY_REGISTERED(address market);

    /// @notice Error for when a market is not registered
    error MARKET_NOT_REGISTERED(address market);

    /// @notice Error for when a market is not registered
    error SAME_SWAP_TOKEN_PAIRS(TokenType tokenIn, TokenType tokenOut);

    /// @dev Modifier to validate if a market is registered
    modifier validMarket(address market) {
        MarketInfo memory marketInfo = pendleMarkets[market];
        if (marketInfo.UNDERLYING == address(0))
            revert MARKET_NOT_REGISTERED(market);
        _;
    }

    /// @dev Modifier to validate if an amount is non-zero
    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Constructor to initialize the contract with the Pendle Router address
    /// @param _pendleRouter Address of the Pendle Router
    constructor(address _pendleRouter) Ownable(msg.sender) {
        pendleRouter = _pendleRouter;
    }

    /// @notice Retrieves the token address from a market and token type
    /// @param market Address of the Pendle market
    /// @param tokenType Type of the token
    /// @return token Address of the corresponding token
    function getTokenFromMarketByType(
        address market,
        TokenType tokenType
    ) public view returns (address token) {
        MarketInfo memory marketInfo = pendleMarkets[market];
        if (tokenType == TokenType.UNDERLYING) token = marketInfo.UNDERLYING;
        if (tokenType == TokenType.SY) token = marketInfo.SY;
        if (tokenType == TokenType.PT) token = marketInfo.PT;
        if (tokenType == TokenType.YT) token = marketInfo.YT;
        if (tokenType == TokenType.LP) token = marketInfo.LP;
    }

    /// @notice Retrieves the token infos from a pendle market address
    /// @param market Address of the Pendle market
    function getPendleMarketInfo(
        address market
    ) external view returns (MarketInfo memory marketInfo) {
        marketInfo = pendleMarkets[market];
    }

    /// @notice Retrieves the user info from a pendle market address and user address
    /// @param user Address of user
    /// @param market Address of the Pendle market
    function getUserInfo(
        address user,
        address market
    ) external view returns (UserInfo memory userInfo) {
        userInfo = userInfos[user][market];
    }

    /// @notice Adds a new Pendle market
    /// @dev Only callable by the contract owner
    /// @param market Address of the Pendle market to add
    function addPendleMarket(address market) external onlyOwner {
        MarketInfo storage marketInfo = pendleMarkets[market];
        if (marketInfo.UNDERLYING != address(0)) {
            revert MARKET_ALREADY_REGISTERED(market);
        }

        // read from PMarket
        (
            IStandardizedYield SY,
            IPPrincipalToken PT,
            IPYieldToken YT
        ) = IPMarket(market).readTokens();

        marketInfo.UNDERLYING = IStandardizedYield(SY).yieldToken(); // read yieldToken from SY token
        marketInfo.SY = address(SY);
        marketInfo.PT = address(PT);
        marketInfo.YT = address(YT);
        marketInfo.LP = address(market);
    }

    /// @notice Deposits tokens into AM
    /// @param market Address of the Pendle market
    /// @param tokenInType Type of the input token
    /// @param amountIn Amount of the input token
    function deposit(
        address market,
        TokenType tokenInType,
        uint256 amountIn
    ) external {
        _deposit(market, tokenInType, amountIn);
    }

    /// @notice Withdraws tokens from AM
    /// @param market Address of the Pendle market
    /// @param tokenOutType Type of the output token
    function withdraw(address market, TokenType tokenOutType) external {
        _withdraw(market, tokenOutType);
    }

    /// @notice Converts a user's deposited token to another token
    /// @dev Converts the entire deposited amount
    /// @param market Address of the Pendle market
    /// @param tokenOutType Type of the output token
    function convert(address market, TokenType tokenOutType) external {
        UserInfo memory userInfo = userInfos[msg.sender][market];
        _convert(market, userInfo.tokenType, userInfo.amount, tokenOutType);
    }

    /// @notice Performs a swap between tokens
    /// @param market Address of the Pendle market
    /// @param tokenInType Type of the input token
    /// @param amountIn Amount of the input token
    /// @param tokenOutType Type of the output token
    function swap(
        address market,
        TokenType tokenInType,
        uint256 amountIn,
        TokenType tokenOutType
    ) external {
        if (tokenInType == tokenOutType) {
            revert SAME_SWAP_TOKEN_PAIRS(tokenInType, tokenOutType);
        }
        _deposit(market, tokenInType, amountIn);
        _convert(market, tokenInType, amountIn, tokenOutType);
        _withdraw(market, tokenOutType);
    }

    /// @dev Internal Deposit function
    /// @param market address of pendle market
    /// @param tokenInType type of input token
    /// @param amount amount of input token
    function _deposit(
        address market,
        TokenType tokenInType,
        uint256 amount
    ) internal validMarket(market) validAmount(amount) {
        address token = getTokenFromMarketByType(market, tokenInType);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        UserInfo storage userInfo = userInfos[msg.sender][market];
        if (userInfo.amount == 0) {
            userInfo.tokenType = tokenInType;
            userInfo.amount = amount;
        } else if (userInfo.tokenType == tokenInType) {
            userInfo.amount += amount;
        } else {
            revert USER_ALREDY_DEPOSITED(msg.sender, market);
        }

        // emit event
        emit Deposited(msg.sender, market, tokenInType, amount);
    }

    /// @dev Internal Withdraw function
    /// @param market address of pendle market
    /// @param tokenOutType type of output token
    function _withdraw(
        address market,
        TokenType tokenOutType
    ) internal validMarket(market) {
        UserInfo memory userInfo = userInfos[msg.sender][market];
        uint256 amountOut = userInfo.amount;

        // convert user's deposited token to output token if they are different
        if (userInfo.tokenType != tokenOutType) {
            amountOut = _convert(
                market,
                userInfo.tokenType,
                userInfo.amount,
                tokenOutType
            );
        }

        // transfer token to user
        address tokenOut = getTokenFromMarketByType(market, tokenOutType);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        // update storage
        delete userInfos[msg.sender][market];

        // emit event
        emit Withdrew(msg.sender, market, tokenOutType, amountOut);
    }

    /// @dev Internal Convert function
    /// @param market address of pendle market
    /// @param tokenInType type of input token
    /// @param amountIn amount of input token
    /// @param tokenOutType type of output token
    function _convert(
        address market,
        TokenType tokenInType,
        uint256 amountIn,
        TokenType tokenOutType
    ) internal validMarket(market) returns (uint256 amountOut) {
        // convert via pendle router
        amountOut = _swapOnPendle(market, tokenInType, amountIn, tokenOutType);

        // update storage info
        UserInfo storage userInfo = userInfos[msg.sender][market];
        userInfo.tokenType = tokenOutType;
        userInfo.amount = amountOut;

        // emit event
        emit Converted(
            msg.sender,
            market,
            tokenInType,
            amountIn,
            tokenOutType,
            amountOut
        );
    }

    /// @dev swap using pendle router
    function _swapOnPendle(
        address market,
        TokenType tokenInType,
        uint256 amountIn,
        TokenType tokenOutType
    ) internal returns (uint256 amountOut) {
        address tokenIn = getTokenFromMarketByType(market, tokenInType);
        address syToken = getTokenFromMarketByType(market, TokenType.SY);
        address tokenOut = getTokenFromMarketByType(market, tokenOutType);

        // step1: input token conversion to Sy token
        uint256 syAmount;
        if (tokenInType == TokenType.UNDERLYING) {
            syAmount = _swapTokenToSy(tokenIn, amountIn, syToken);
        } else if (tokenInType == TokenType.PT) {
            syAmount = _swapPtToSy(market, tokenIn, amountIn);
        } else if (tokenInType == TokenType.YT) {
            syAmount = _swapYtToSy(market, tokenIn, amountIn);
        } else if (tokenInType == TokenType.LP) {
            syAmount = _swapLPToSy(market, tokenIn, amountIn);
        } else {
            syAmount = amountIn;
        }

        // step2: Sy token conversion to output token
        if (tokenOutType == TokenType.UNDERLYING) {
            amountOut = _swapSyToToken(syToken, syAmount, tokenOut);
        } else if (tokenOutType == TokenType.PT) {
            amountOut = _swapSyToPt(market, syToken, syAmount);
        } else if (tokenOutType == TokenType.YT) {
            amountOut = _swapSyToYt(market, syToken, syAmount);
        } else if (tokenOutType == TokenType.LP) {
            amountOut = _swapSyToLP(market, syToken, syAmount);
        } else {
            amountOut = syAmount;
        }
    }

    /// @dev token => SY
    function _swapTokenToSy(
        address tokenIn,
        uint256 amountIn,
        address SY
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(pendleRouter, amountIn);
        amountOut = IPendleRouter(pendleRouter).mintSyFromToken(
            address(this),
            address(SY), // address of SY
            0,
            createTokenInputStruct(tokenIn, amountIn)
        );
    }

    /// @dev PT => SY
    function _swapPtToSy(
        address market,
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).swapExactPtForSy(
            address(this),
            market,
            amountIn,
            0,
            emptyLimitOrderData
        );
    }

    /// @dev YT => SY
    function _swapYtToSy(
        address market,
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).swapExactYtForSy(
            address(this),
            market,
            amountIn,
            0,
            emptyLimitOrderData
        );
    }

    /// @dev LP => SY
    function _swapLPToSy(
        address market,
        address tokenIn,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).removeLiquiditySingleSy(
            address(this),
            market,
            amountIn,
            0,
            emptyLimitOrderData
        );
    }

    /// @dev SY => token
    function _swapSyToToken(
        address SY,
        uint256 amountIn,
        address tokenOut
    ) internal returns (uint256 amountOut) {
        IERC20(SY).approve(pendleRouter, amountIn);
        amountOut = IPendleRouter(pendleRouter).redeemSyToToken(
            address(this),
            address(SY), // address of SY
            amountIn,
            createTokenOutputStruct(tokenOut, 0)
        );
    }

    /// @dev SY => PT
    function _swapSyToPt(
        address market,
        address SY,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(SY).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).swapExactSyForPt(
            address(this),
            market,
            amountIn,
            0,
            defaultApprox,
            emptyLimitOrderData
        );
    }

    /// @dev SY => YT
    function _swapSyToYt(
        address market,
        address SY,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(SY).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).swapExactSyForYt(
            address(this),
            market,
            amountIn,
            0,
            defaultApprox,
            emptyLimitOrderData
        );
    }

    /// @dev SY => LP
    function _swapSyToLP(
        address market,
        address SY,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        IERC20(SY).approve(pendleRouter, amountIn);
        (amountOut, ) = IPendleRouter(pendleRouter).addLiquiditySingleSy(
            address(this),
            market,
            amountIn,
            0,
            defaultApprox,
            emptyLimitOrderData
        );
    }
}

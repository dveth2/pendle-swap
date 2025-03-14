// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PendleAssetManager} from "../src/PendleAssetManager.sol";
import {IPendleRouter} from "../src/interfaces/IPendleRouter.sol";
import {IAavePool} from "../src/interfaces/IAavePool.sol";

contract TestPendleAssetManager is Test {
    using SafeERC20 for IERC20;

    /// @dev PendleAssetManager
    PendleAssetManager pam;
    address constant PENDLE_ROUTER =
        address(0x888888888889758F76e7103c6CbF23ABbF58F946);

    /// @dev eUSDe market tokens
    address constant PENDLE_MARKET =
        address(0x85667e484a32d884010Cf16427D90049CCf46e97);
    address constant PENDLE_MARKET_UNDERLYING =
        address(0x90D2af7d622ca3141efA4d8f1F24d86E5974Cc8F);
    address constant PENDLE_MARKET_SY =
        address(0x7ac8ca87959b1d5EDfe2df5325A37c304DCea4D0);
    address constant PENDLE_MARKET_PT =
        address(0x50D2C7992b802Eef16c04FeADAB310f31866a545);
    address constant PENDLE_MARKET_YT =
        address(0x708dD9B344dDc7842f44C7b90492CF0e1E3eb868);
    address constant PENDLE_MARKET_LP =
        address(0x85667e484a32d884010Cf16427D90049CCf46e97);

    /// @dev test purpose
    address[5] public marketTokens = [
        PENDLE_MARKET_UNDERLYING,
        PENDLE_MARKET_SY,
        PENDLE_MARKET_PT,
        PENDLE_MARKET_YT,
        PENDLE_MARKET_LP
    ];

    /// @dev test accounts
    address constant OWNER = address(0x111);
    address constant ALICE = address(0x222);

    /// @dev Util function to add a new pendle market
    function addPendleMarket(address pendleMarket) public {
        vm.startPrank(OWNER);
        pam.addPendleMarket(pendleMarket);
        vm.stopPrank();
    }

    /// @dev Util function to deposit token to market
    function deposit(
        address user,
        address market,
        PendleAssetManager.TokenType tokenType,
        uint256 amount
    ) public {
        vm.startPrank(user);
        pam.deposit(market, tokenType, amount);
        vm.stopPrank();
    }

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth");

        // initialize PendleAssetManager
        vm.startPrank(OWNER);
        pam = new PendleAssetManager(PENDLE_ROUTER);
        vm.stopPrank();

        // prepare tokens for testing wallets - ALICE
        address[1] memory users = [ALICE];
        for (uint256 index = 0; index < users.length; index++) {
            deal(PENDLE_MARKET_UNDERLYING, users[index], 1_000_000e18);
            deal(PENDLE_MARKET_SY, users[index], 1_000_000e18);
            deal(PENDLE_MARKET_PT, users[index], 1_000_000e18);
            deal(PENDLE_MARKET_YT, users[index], 1_000_000e18);
            deal(PENDLE_MARKET_LP, users[index], 1_000_000e18);
        }

        // approve tokens(UNDERLYING, SY, PT, YT) to PAM contract
        for (uint256 index = 0; index < users.length; index++) {
            vm.startPrank(users[index]);
            IERC20(PENDLE_MARKET_UNDERLYING).forceApprove(
                address(pam),
                type(uint256).max
            );
            IERC20(PENDLE_MARKET_SY).forceApprove(
                address(pam),
                type(uint256).max
            );
            IERC20(PENDLE_MARKET_PT).forceApprove(
                address(pam),
                type(uint256).max
            );
            IERC20(PENDLE_MARKET_YT).forceApprove(
                address(pam),
                type(uint256).max
            );
            IERC20(PENDLE_MARKET_LP).forceApprove(
                address(pam),
                type(uint256).max
            );
            vm.stopPrank();
        }
    }

    function test_AddPendleMarket() public {
        emit log("[start] add Pendle Market...");

        address pendleMarket = PENDLE_MARKET;

        vm.startPrank(ALICE);

        // should be reverted when caller is not owner
        vm.expectRevert();
        pam.addPendleMarket(pendleMarket);

        // should be success when new pendle market is added
        vm.startPrank(OWNER);
        pam.addPendleMarket(pendleMarket);

        // should be reverted when pendle market was already registered
        vm.expectRevert();
        pam.addPendleMarket(pendleMarket);

        vm.stopPrank();

        emit log("[success] add Pendle Market...");
    }

    function test_getPendleMarketInfo() public {
        addPendleMarket(PENDLE_MARKET);

        PendleAssetManager.MarketInfo memory marketInfo = pam
            .getPendleMarketInfo(PENDLE_MARKET);
        assertEq(marketInfo.UNDERLYING, PENDLE_MARKET_UNDERLYING);
        assertEq(marketInfo.SY, PENDLE_MARKET_SY);
        assertEq(marketInfo.PT, PENDLE_MARKET_PT);
        assertEq(marketInfo.YT, PENDLE_MARKET_YT);
        assertEq(marketInfo.LP, PENDLE_MARKET_LP);
    }

    function test_getTokenFromMarketByType() public {
        addPendleMarket(PENDLE_MARKET);

        address UNDERLYING = pam.getTokenFromMarketByType(
            PENDLE_MARKET,
            PendleAssetManager.TokenType.UNDERLYING
        );
        address SY = pam.getTokenFromMarketByType(
            PENDLE_MARKET,
            PendleAssetManager.TokenType.SY
        );
        address PT = pam.getTokenFromMarketByType(
            PENDLE_MARKET,
            PendleAssetManager.TokenType.PT
        );
        address YT = pam.getTokenFromMarketByType(
            PENDLE_MARKET,
            PendleAssetManager.TokenType.YT
        );
        address LP = pam.getTokenFromMarketByType(
            PENDLE_MARKET,
            PendleAssetManager.TokenType.LP
        );
        assertEq(UNDERLYING, PENDLE_MARKET_UNDERLYING);
        assertEq(SY, PENDLE_MARKET_SY);
        assertEq(PT, PENDLE_MARKET_PT);
        assertEq(YT, PENDLE_MARKET_YT);
        assertEq(LP, PENDLE_MARKET_LP);
    }

    function test_Fuzz_Deposit(uint8 rdmIn1, uint8 rmdIn2) public {
        // 5 edge cases (UNDERLYING - 0, SY - 1, PT - 2, YT - 3, LP - 4)
        uint256 _inTokenType0 = rdmIn1 % 5;
        uint256 _inTokenType1 = rmdIn2 % 5;
        vm.assume(rdmIn1 < 5);
        vm.assume(_inTokenType0 != _inTokenType1);

        // add pendle market
        address market = PENDLE_MARKET;
        addPendleMarket(market);

        address user = ALICE;
        uint256 amount = 1e18;
        PendleAssetManager.TokenType inTokenType0 = PendleAssetManager
            .TokenType(_inTokenType0);
        PendleAssetManager.TokenType inTokenType1 = PendleAssetManager
            .TokenType(_inTokenType1);

        vm.startPrank(user);

        // should be success when tries to deposit the same asset 2 times
        pam.deposit(market, inTokenType0, amount);
        pam.deposit(market, inTokenType0, amount);

        // should be reverted when tries to deposit other asset
        vm.expectRevert();
        pam.deposit(market, inTokenType1, amount);

        PendleAssetManager.UserInfo memory userInfo = pam.getUserInfo(
            user,
            market
        );

        assertEq(userInfo.amount, 2 * amount);
        assertEq(uint256(userInfo.tokenType), uint256(inTokenType0));
    }

    function test_Fuzz_Convert(uint8 rdmIn, uint8 rmdOut) public {
        // 5 edge cases (UNDERLYING - 0, SY - 1, PT - 2, YT - 3, LP - 4)

        uint256 _inTokenType = rdmIn % 5;
        uint256 _outTokenType = rmdOut % 5;
        vm.assume(rdmIn < 5);
        vm.assume(_inTokenType != _outTokenType);

        // add pendle market
        address market = PENDLE_MARKET;
        addPendleMarket(market);

        address user = ALICE;
        uint256 amount = 1e18;

        PendleAssetManager.TokenType inTokenType = PendleAssetManager.TokenType(
            _inTokenType
        );
        PendleAssetManager.TokenType outTokenType = PendleAssetManager
            .TokenType(_outTokenType);

        // deposit
        deposit(user, market, inTokenType, amount);

        // convert
        vm.startPrank(user);
        pam.convert(market, outTokenType);

        // storage change check
        PendleAssetManager.UserInfo memory userInfo = pam.getUserInfo(
            user,
            market
        );
        // assertGt(userInfo.amount, 0);
        assertEq(uint256(userInfo.tokenType), uint256(outTokenType));
    }

    function test_Fuzz_Withdraw(uint8 rdmIn, uint8 rmdOut) public {
        // 5 edge cases (UNDERLYING - 0, SY - 1, PT - 2, YT - 3, LP - 4)
        uint256 _inTokenType = rdmIn % 5;
        uint256 _outTokenType = rmdOut % 5;

        vm.assume(rdmIn < 5);
        vm.assume(rmdOut < 5);
        vm.assume(_inTokenType != _outTokenType);

        // add pendle market
        address market = PENDLE_MARKET;
        addPendleMarket(market);

        address user = ALICE;
        uint256 amount = 1e18;

        PendleAssetManager.TokenType inTokenType = PendleAssetManager.TokenType(
            _inTokenType
        );
        PendleAssetManager.TokenType outTokenType = PendleAssetManager
            .TokenType(_outTokenType);

        address outToken = marketTokens[_outTokenType];

        // deposit
        deposit(user, market, inTokenType, amount);

        // withdraw
        vm.startPrank(user);
        uint256 outTokenBalBefore = IERC20(outToken).balanceOf(user);
        pam.withdraw(market, outTokenType);
        uint256 outTokenBalAfter = IERC20(outToken).balanceOf(user);

        // storage change check
        PendleAssetManager.UserInfo memory userInfo = pam.getUserInfo(
            user,
            market
        );
        assertEq(userInfo.amount, 0);
        assertEq(uint256(userInfo.tokenType), 0);

        // out token balance check
        assertGe(outTokenBalAfter, outTokenBalBefore);
    }

    function test_Fuzz_Swap(uint8 rdmIn, uint8 rmdOut) public {
        // 5 edge cases (UNDERLYING - 0, SY - 1, PT - 2, YT - 3, LP - 4)
        uint256 _inTokenType = rdmIn % 5;
        uint256 _outTokenType = rmdOut % 5;

        vm.assume(rdmIn < 5);
        vm.assume(_inTokenType != _outTokenType);

        // add pendle market
        address market = PENDLE_MARKET;
        addPendleMarket(market);

        address user = ALICE;
        uint256 amount = 1e18;

        PendleAssetManager.TokenType inTokenType = PendleAssetManager.TokenType(
            _inTokenType
        );
        PendleAssetManager.TokenType outTokenType = PendleAssetManager
            .TokenType(_outTokenType);

        address inToken = marketTokens[_inTokenType];
        address outToken = marketTokens[_outTokenType];

        // swap
        vm.startPrank(user);

        uint256 inTokenBalBefore = IERC20(inToken).balanceOf(user);
        uint256 outTokenBalBefore = IERC20(outToken).balanceOf(user);

        pam.swap(market, inTokenType, amount, outTokenType);

        uint256 inTokenBalAfter = IERC20(inToken).balanceOf(user);
        uint256 outTokenBalAfter = IERC20(outToken).balanceOf(user);

        // storage change check
        PendleAssetManager.UserInfo memory userInfo = pam.getUserInfo(
            user,
            market
        );
        assertEq(userInfo.amount, 0);
        assertEq(uint256(userInfo.tokenType), 0);

        // in token balance check
        assertGe(inTokenBalBefore, inTokenBalAfter);

        // out token balance check
        assertGe(outTokenBalAfter, outTokenBalBefore);
    }
}

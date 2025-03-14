// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.26;

interface IAavePool {
    function supply(
        address token,
        uint amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface ILiquidator {
    function liquidateAccount(address account) external;
}

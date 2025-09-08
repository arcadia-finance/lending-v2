/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface ILiquidator {
    function liquidateAccount(address account) external;
}

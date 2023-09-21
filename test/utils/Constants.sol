/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */

pragma solidity 0.8.19;

library Constants {
    uint72 internal constant interestRate = 5e16; //5% with 18 decimals precision
    uint40 internal constant utilisationThreshold = 8e4; //80% with 5 decimals precision
}

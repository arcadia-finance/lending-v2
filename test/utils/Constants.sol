/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

library Constants {
    uint72 internal constant interestRate = 5e16; //5% with 18 decimals precision
    uint16 internal constant utilisationThreshold = 8e3; //80% with 4 decimals precision
}

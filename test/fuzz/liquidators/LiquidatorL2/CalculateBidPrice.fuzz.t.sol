/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "calculateBidPrice" of contract "LiquidatorL2".
 */
contract CalculateBidPrice_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    // ToDo
}

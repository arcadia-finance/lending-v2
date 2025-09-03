/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";
import { LogExpMath } from "../../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the function "calculateBidPrice" of contract "LiquidatorL1".
 */
contract CalculateBidPrice_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    // ToDo
}

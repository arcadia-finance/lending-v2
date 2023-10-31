/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";

import { LiquidatorExtension_NEW } from "../../utils/Extensions.sol";
/**
 * @notice Fuzz tests for the function "constructor" of contract "Liquidator".
 */

contract Constructor_Liquidator_Fuzz_Test_NEW is Liquidator_Fuzz_Test_NEW {
    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LiquidatorExtension_NEW internal liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        liquidator_ = new LiquidatorExtension_NEW(address(factory));

        assertEq(liquidator_.getLocked(), 1);
        assertEq(liquidator_.getPenaltyWeight(), 5);
        assertEq(liquidator_.getInitiatorRewardWeight(), 1);
        assertEq(liquidator_.getClosingRewardWeight(), 1);
    }
}

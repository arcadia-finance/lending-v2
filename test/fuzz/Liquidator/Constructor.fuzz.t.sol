/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LiquidatorExtension } from "../../utils/Extensions.sol";
/**
 * @notice Fuzz tests for the function "constructor" of contract "Liquidator".
 */

contract Constructor_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LiquidatorExtension internal liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        liquidator_ = new LiquidatorExtension(address(factory));

        assertEq(liquidator_.getLocked(), 1);
        assertEq(liquidator_.getPenaltyWeight(), 5);
        assertEq(liquidator_.getInitiatorRewardWeight(), 1);
        assertEq(liquidator_.getClosingRewardWeight(), 1);
    }
}

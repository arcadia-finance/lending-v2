/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { Liquidator } from "../../../src/Liquidator.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "Liquidator".
 */
contract Constructor_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    Liquidator internal liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_) public {
        liquidator_ = new Liquidator(factory_);

        assertEq(liquidator_.factory(), factory_);
        assertEq(liquidator_.penaltyWeight(), 5);
        assertEq(liquidator_.initiatorRewardWeight(), 1);
        assertEq(liquidator_.startPriceMultiplier(), 150);
        assertEq(liquidator_.minPriceMultiplier(), 60);
        assertEq(liquidator_.cutoffTime(), 14_400);
        assertEq(liquidator_.base(), 999_807_477_651_317_446);
    }
}

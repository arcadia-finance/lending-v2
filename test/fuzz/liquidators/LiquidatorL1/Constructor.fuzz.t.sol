/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";

import { LiquidatorL1 } from "../../../../src/liquidators/LiquidatorL1.sol";
import { LiquidatorL1Extension } from "../../../utils/extensions/LiquidatorL1Extension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "LiquidatorL1".
 */
contract Constructor_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                          TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LiquidatorL1Extension internal _liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address factory_) public {
        vm.expectEmit(true, true, true, true);
        emit LiquidatorL1.AuctionCurveParametersSet(999_807_477_651_317_446, 14_400, 15_000, 6000);
        _liquidator_ = new LiquidatorL1Extension(users.owner, factory_);

        assertEq(_liquidator_.getAccountFactory(), factory_);
        assertEq(_liquidator_.getBase(), 999_807_477_651_317_446);
        assertEq(_liquidator_.getCutoffTime(), 14_400);
        assertEq(_liquidator_.getStartPriceMultiplier(), 15_000);
        assertEq(_liquidator_.getMinPriceMultiplier(), 6000);
    }
}

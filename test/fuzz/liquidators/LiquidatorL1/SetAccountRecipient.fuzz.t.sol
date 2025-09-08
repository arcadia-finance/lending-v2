/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "setAccountRecipient" of contract "LiquidatorL1".
 */
contract SetAccountRecipient_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAssetRecipient_NonRiskManager(address unprivilegedAddress_, address newAssetRecipient)
        public
    {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(LiquidatorErrors.NotAuthorized.selector);
        liquidator_.setAccountRecipient(address(pool), newAssetRecipient);
        vm.stopPrank();
    }

    function testFuzz_Success_setAssetRecipient(address newAssetRecipient) public {
        vm.prank(users.riskManager);
        liquidator_.setAccountRecipient(address(pool), newAssetRecipient);
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "setAccountRecipient" of contract "LiquidatorL2".
 */
contract SetAccountRecipient_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
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
        liquidator.setAccountRecipient(address(pool), newAssetRecipient);
        vm.stopPrank();
    }

    function testFuzz_Success_setAssetRecipient(address newAssetRecipient) public {
        vm.prank(users.riskManager);
        liquidator.setAccountRecipient(address(pool), newAssetRecipient);
    }
}

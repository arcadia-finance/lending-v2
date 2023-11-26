/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { LiquidatorErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "setAssetRecipient" of contract "Liquidator".
 */
contract SetAssetRecipient_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
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
        liquidator.setAssetRecipient(address(pool), newAssetRecipient);
        vm.stopPrank();
    }

    function testFuzz_Success_setAssetRecipient(address newAssetRecipient) public {
        vm.prank(users.riskManager);
        liquidator.setAssetRecipient(address(pool), newAssetRecipient);
    }
}

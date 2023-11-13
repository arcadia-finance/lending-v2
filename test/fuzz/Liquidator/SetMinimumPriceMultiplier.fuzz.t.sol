/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMinimumPriceMultiplier" of contract "Liquidator".
 */
contract SetMinimumPriceMultiplier_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMinimumPriceMultiplier_tooHigh(uint8 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier >= 91);

        // Given When Then: a owner attempts to set the minimum price multiplier, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_MultiplierTooHigh.selector);
        liquidator.setMinimumPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Success_setMinimumPriceMultiplier(uint8 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier < 91);
        // Given: the owner is the users.creatorAddress

        vm.startPrank(users.creatorAddress);
        // When: the owner sets the minimum price multiplier
        vm.expectEmit(true, true, true, true);
        emit MinimumPriceMultiplierSet(priceMultiplier);
        liquidator.setMinimumPriceMultiplier(priceMultiplier);
        vm.stopPrank();

        // Then: multiplier sets correctly
        assertEq(liquidator.getMinPriceMultiplier(), priceMultiplier);
    }
}

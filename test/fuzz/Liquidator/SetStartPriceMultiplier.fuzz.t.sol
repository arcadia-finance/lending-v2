/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setStartPriceMultiplier" of contract "Liquidator".
 */

contract SetStartPriceMultiplier_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setStartPriceMultiplier_NonOwner(address unprivilegedAddress_, uint16 priceMultiplier)
        public
    {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setStartPriceMultiplier_tooHigh(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier >= 300);

        // Given When Then: a owner attempts to set the start price multiplier, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_MultiplierTooHigh.selector);
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setStartPriceMultiplier_tooLow(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier <= 100);

        // Given When Then: a owner attempts to set the start price multiplier, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_MultiplierTooLow.selector);
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Success_setStartPriceMultiplier(uint16 priceMultiplier) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(priceMultiplier > 100);
        vm.assume(priceMultiplier < 301);

        // Given: the owner is the users.creatorAddress
        vm.startPrank(users.creatorAddress);
        // When: the owner sets the start price multiplier
        vm.expectEmit(true, true, true, true);
        emit StartPriceMultiplierSet(priceMultiplier);
        liquidator.setStartPriceMultiplier(priceMultiplier);
        vm.stopPrank();

        // Then: multiplier sets correctly
        assertEq(liquidator.getStartPriceMultiplier(), priceMultiplier);
    }
}

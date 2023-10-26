/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "startLiquidation" of contract "LendingPool".
 */
contract StartLiquidation_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_StartLiquidation_NonLiquidator(
        address account,
        address unprivilegedAddress,
        uint256 openDebt,
        uint256 liquidationIncentives,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight
    ) public {
        // Given: unprivilegedAddress is not the liquidator
        vm.assume(unprivilegedAddress != address(liquidator));

        // When: unprivilegedAddress settles a liquidation
        // Then: settleLiquidation should revert with error LendingPool_OnlyLiquidator
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(LendingPool_OnlyLiquidator.selector);
        pool.startLiquidation(account, initiatorRewardWeight, penaltyWeight, closingRewardWeight);
        vm.stopPrank();
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setFixedLiquidationCost" of contract "LendingPool".
 */
contract SetFixedLiquidationCost_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_setFixedLiquidationCost_Unauthorised(address unprivilegedAddress, uint96 fixedLiquidationCost)
        public
    {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setFixedLiquidationCost(fixedLiquidationCost);
        vm.stopPrank();
    }

    function testSuccess_setFixedLiquidationCost(uint96 fixedLiquidationCost) public {
        vm.prank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit FixedLiquidationCostSet(fixedLiquidationCost);
        pool.setFixedLiquidationCost(fixedLiquidationCost);

        assertEq(pool.fixedLiquidationCost(), fixedLiquidationCost);
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMaxLiquidationFees" of contract "LendingPool".
 */

contract SetMaxLiquidationFees_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxLiquidationFees_Unauthorised(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMaxLiquidationFees(100, 0);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxLiquidationFees(uint80 maxFeeInitiation, uint80 maxFeeClosing) public {
        vm.prank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxLiquidationFeesSet(maxFeeInitiation, maxFeeClosing);
        pool.setMaxLiquidationFees(maxFeeInitiation, maxFeeClosing);

        assertEq(pool.getMaxInitiationFee(), maxFeeInitiation);
        assertEq(pool.getMaxTerminationFee(), maxFeeClosing);
    }
}

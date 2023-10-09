/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { Errors } from "../../utils/Errors.sol";
/**
 * @notice Fuzz tests for the function "setMaxInitiatorFee" of contract "LendingPool".
 */

contract SetMaxInitiatorFee_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMaxInitiatorFee_Unauthorised(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMaxInitiatorFee(100);
        vm.stopPrank();
    }

    function testFuzz_Success_setMaxInitiatorFee(uint80 maxFee) public {
        vm.prank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxInitiatorFeeSet(maxFee);
        pool.setMaxInitiatorFee(maxFee);

        assertEq(pool.maxInitiatorFee(), maxFee);
    }
}

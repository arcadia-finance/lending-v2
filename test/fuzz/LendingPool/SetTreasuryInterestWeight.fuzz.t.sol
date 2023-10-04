/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { Errors } from "../../../src/libraries/Errors.sol";
/**
 * @notice Fuzz tests for the function "setTreasuryInterestWeight" of contract "LendingPool".
 */

contract SetTreasuryInterestWeight_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setTreasuryInterestWeight_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasuryInterestWeight(5);
        vm.stopPrank();
    }

    function testFuzz_Success_setTreasuryInterestWeight() public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TreasuryInterestWeightSet(5);
        pool.setTreasuryInterestWeight(5);
        vm.stopPrank();

        assertEq(pool.totalInterestWeight(), 95);
        assertEq(pool.interestWeightTreasury(), 5);

        vm.startPrank(users.creatorAddress);
        pool.setTreasuryInterestWeight(10);
        vm.stopPrank();

        assertEq(pool.totalInterestWeight(), 100);
        assertEq(pool.interestWeightTreasury(), 10);
    }
}

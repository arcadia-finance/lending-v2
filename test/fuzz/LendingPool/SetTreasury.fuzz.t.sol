/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setTreasury" of contract "LendingPool".
 */
contract SetTreasury_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setTreasury_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasury(users.creatorAddress);
        vm.stopPrank();
    }

    function testFuzz_Success_setTreasury() public {
        vm.prank(users.creatorAddress);
        pool.setTreasury(users.creatorAddress);

        assertEq(pool.getTreasury(), users.creatorAddress);
    }
}

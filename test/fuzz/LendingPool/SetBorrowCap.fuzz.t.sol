/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setBorrowCap" of contract "LendingPool".
 */
contract SetBorrowCap_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBorrowCap_InvalidOwner(address unprivilegedAddress, uint128 borrowCap) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setBorrowCap(borrowCap);
        vm.stopPrank();
    }

    function testFuzz_Success_setBorrowCap(uint128 borrowCap) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit BorrowCapSet(borrowCap);
        pool.setBorrowCap(borrowCap);
        vm.stopPrank();

        assertEq(pool.borrowCap(), borrowCap);
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "LendingPool".
 */
contract TransferOwnership_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferOwnership_nonOwner(address unprivilegedAddress, address newOwner) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_Success_transferOwnership(address newOwner) public {
        vm.startPrank(users.creatorAddress);
        pool.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(newOwner, pool.owner());
    }
}

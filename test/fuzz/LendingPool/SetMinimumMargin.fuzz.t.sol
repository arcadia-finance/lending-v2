/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMinimumMargin" of contract "LendingPool".
 */
contract SetMinimumMargin_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setMinimumMargin_Unauthorised(address unprivilegedAddress, uint96 minimumMargin) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMinimumMargin(minimumMargin);
        vm.stopPrank();
    }

    function testFuzz_Success_setMinimumMargin(uint96 minimumMargin) public {
        vm.prank(users.creatorAddress);
        pool.setMinimumMargin(minimumMargin);

        assertEq(pool.getMinimumMargin(), minimumMargin);
    }
}

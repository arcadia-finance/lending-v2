/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAccountVersion" of contract "LendingPool".
 */
contract SetAccountVersion_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAccountVersion_NonOwner(address unprivilegedAddress, uint256 accountVersion, bool valid)
        public
    {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setAccountVersion(accountVersion, valid);
        vm.stopPrank();
    }

    function testFuzz_Success_setAccountVersion_setValid(uint256 accountVersion) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit ValidAccountVersionsUpdated(accountVersion, true);
        pool.setAccountVersion(accountVersion, true);
        vm.stopPrank();

        assertTrue(pool.isValidVersion(accountVersion));
    }

    function testFuzz_Success_setAccountVersion_setInvalid(uint256 accountVersion) public {
        vm.prank(users.creatorAddress);
        pool.setIsValidVersion(accountVersion, true);

        vm.prank(users.creatorAddress);
        pool.setAccountVersion(accountVersion, false);

        assertTrue(!pool.isValidVersion(accountVersion));
    }
}

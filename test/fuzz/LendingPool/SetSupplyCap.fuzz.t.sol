/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setSupplyCap" of contract "LendingPool".
 */
contract SetSupplyCap_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setSupplyCap_InvalidOwner(address unprivilegedAddress, uint128 supplyCap) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setSupplyCap(supplyCap);
        vm.stopPrank();
    }

    function testFuzz_Success_setSupplyCap(uint128 supplyCap) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit SupplyCapSet(supplyCap);
        pool.setSupplyCap(supplyCap);
        vm.stopPrank();

        assertEq(pool.supplyCap(), supplyCap);
    }
}

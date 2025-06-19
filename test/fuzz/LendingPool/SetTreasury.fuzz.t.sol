/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

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
        vm.assume(unprivilegedAddress != users.owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTreasury(users.owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_setTreasury_InvalidTreasury() public {
        vm.prank(users.owner);
        vm.expectRevert(LendingPoolErrors.InvalidTreasury.selector);
        pool.setTreasury(address(srTranche));
    }

    function testFuzz_Success_setTreasury(
        address oldTreasury,
        address newTreasury,
        uint16 interestWeight_,
        uint16 liquidationWeight
    ) public {
        vm.assume(oldTreasury != newTreasury);
        vm.assume(oldTreasury != address(srTranche));
        vm.assume(oldTreasury != address(jrTranche));
        vm.assume(newTreasury != address(srTranche));
        vm.assume(newTreasury != address(jrTranche));

        vm.startPrank(users.owner);
        pool.setTreasury(oldTreasury);
        pool.setTreasuryWeights(interestWeight_, liquidationWeight);
        vm.stopPrank();

        vm.prank(users.owner);
        pool.setTreasury(newTreasury);

        assertEq(pool.getTreasury(), newTreasury);
        assertEq(pool.getInterestWeight(oldTreasury), 0);
        assertEq(pool.getInterestWeight(newTreasury), interestWeight_);
    }
}

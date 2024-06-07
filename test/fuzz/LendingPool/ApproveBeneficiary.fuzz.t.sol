/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "approveBeneficiary" of contract "LendingPool".
 */
contract ApproveBeneficiary_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_approveBeneficiary_NonAccount(address beneficiary, uint256 amount, address nonAccount)
        public
    {
        vm.assume(nonAccount != address(account));
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.approveBeneficiary(beneficiary, amount, nonAccount);
    }

    function testFuzz_Revert_approveBeneficiary_Unauthorised(
        address beneficiary,
        uint256 amount,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != users.accountOwner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.approveBeneficiary(beneficiary, amount, address(account));
        vm.stopPrank();
    }

    function testFuzz_Success_approveBeneficiary(address beneficiary, uint256 amount) public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.CreditApproval(address(account), users.accountOwner, beneficiary, amount);
        pool.approveBeneficiary(beneficiary, amount, address(account));
        vm.stopPrank();

        assertEq(pool.creditAllowance(address(account), users.accountOwner, beneficiary), amount);
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

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
        vm.assume(nonAccount != address(proxyAccount));
        vm.expectRevert(Unauthorized.selector);
        pool.approveBeneficiary(beneficiary, amount, nonAccount);
    }

    function testFuzz_Revert_approveBeneficiary_Unauthorised(
        address beneficiary,
        uint256 amount,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != users.accountOwner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(Unauthorized.selector);
        pool.approveBeneficiary(beneficiary, amount, address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_approveBeneficiary(address beneficiary, uint256 amount) public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit CreditApproval(address(proxyAccount), users.accountOwner, beneficiary, amount);
        pool.approveBeneficiary(beneficiary, amount, address(proxyAccount));
        vm.stopPrank();

        assertEq(pool.creditAllowance(address(proxyAccount), users.accountOwner, beneficiary), amount);
    }
}

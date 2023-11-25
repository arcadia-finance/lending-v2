/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "Tranche".
 */
contract TransferOwnership_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferOwnership_nonOwner(address unprivilegedAddress, address newOwner) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        tranche.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_Success_transferOwnership(address newOwner) public {
        vm.startPrank(users.creatorAddress);
        tranche.transferOwnership(newOwner);
        vm.stopPrank();

        assertEq(newOwner, tranche.owner());
    }
}

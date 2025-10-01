/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { Tranche } from "../../../src/Tranche.sol";
import { TrancheErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "lock" of contract "Tranche".
 */
contract Lock_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_lock_Unauthorised(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != address(pool));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(TrancheErrors.Unauthorized.selector);
        tranche.lock();
        vm.stopPrank();
    }

    function testFuzz_Success_lock() public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(address(pool));
        vm.expectEmit(true, true, true, true);
        emit Tranche.LockSet(true);
        vm.expectEmit(true, true, true, true);
        emit Tranche.AuctionInProgressSet(false);
        tranche.lock();
        vm.stopPrank();

        assertTrue(tranche.locked());
        assertFalse(tranche.auctionInProgress());
    }
}

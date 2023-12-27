/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAuctionInProgress" of contract "Tranche".
 */
contract SetAuctionInProgress_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAuctionInProgress_Unauthorised(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != address(pool));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(Unauthorized.selector);
        tranche.setAuctionInProgress(true);
        vm.stopPrank();
    }

    function testFuzz_Success_setAuctionInProgress(bool set) public {
        vm.startPrank(address(pool));
        vm.expectEmit(true, true, true, true);
        emit AuctionInProgressSet(set);
        tranche.setAuctionInProgress(set);
        vm.stopPrank();

        assertEq(tranche.auctionInProgress(), set);
    }
}

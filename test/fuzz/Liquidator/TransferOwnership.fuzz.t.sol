/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "transferOwnership" of contract "Liquidator".
 */
contract TransferOwnership_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_transferOwnership_NonOwner(address unprivilegedAddress_, address to) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.transferOwnership(to);
        vm.stopPrank();
    }

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        vm.prank(users.creatorAddress);
        liquidator.transferOwnership(to);

        assertEq(to, liquidator.owner());
    }
}

/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { DebtToken_Fuzz_Test } from "./_DebtToken.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "permit" of contract "DebtToken".
 */
contract Permit_DebtToken_Fuzz_Test is DebtToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DebtToken_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address sender
    ) public {
        vm.startPrank(sender);
        vm.expectRevert(FunctionNotImplemented.selector);
        debt_.permit(owner, spender, value, deadline, v, r, s);
        vm.stopPrank();
    }
}

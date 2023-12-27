/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DebtToken_Fuzz_Test } from "./_DebtToken.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transferFrom" of contract "DebtToken".
 */
contract TransferFrom_DebtToken_Fuzz_Test is DebtToken_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DebtToken_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferFrom(address from, address to, uint256 amount, address sender) public {
        vm.startPrank(sender);
        vm.expectRevert(FunctionNotImplemented.selector);
        debt_.transferFrom(from, to, amount);
        vm.stopPrank();
    }
}

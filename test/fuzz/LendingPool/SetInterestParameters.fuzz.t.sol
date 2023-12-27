/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "SetInterestParameters" of contract "LendingPool".
 */
contract SetInterestParameters_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setInterestParameters_NonOwner(
        address unprivilegedAddress,
        uint8 baseRate_,
        uint8 highSlope_,
        uint8 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);
        vm.stopPrank();
    }

    function testFuzz_Success_setInterestParameters(
        uint8 baseRate_,
        uint8 highSlope_,
        uint8 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        vm.prank(users.creatorAddress);
        pool.setInterestParameters(baseRate_, lowSlope_, highSlope_, utilisationThreshold_);

        (uint256 baseRatePerYear, uint256 lowSlopePerYear, uint256 highSlopePerYear, uint256 utilisationThreshold) =
            pool.getInterestRateVariables();
        assertEq(baseRatePerYear, baseRate_);
        assertEq(highSlopePerYear, highSlope_);
        assertEq(lowSlopePerYear, lowSlope_);
        assertEq(utilisationThreshold, utilisationThreshold_);
    }
}

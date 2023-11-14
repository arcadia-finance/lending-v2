/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the function "setAuctionCurveParameters" of contract "Liquidator".
 */
contract SetAuctionCurveParameters_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAuctionCurveParameters_NonOwner(
        address unprivilegedAddress_,
        uint32 halfLifeTime,
        uint32 cutoffTime
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_BaseTooHigh(uint32 halfLifeTime, uint32 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 8 * 60 * 60, type(uint32).max));

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_HalfLifeTimeTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_BaseTooLow(uint32 halfLifeTime, uint32 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 0, 2 * 60));

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_HalfLifeTimeTooLow.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_AuctionCutoffTimeTooHigh(uint32 halfLifeTime, uint32 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 2 * 60 + 1, 8 * 60 * 60));
        cutoffTime = uint32(bound(cutoffTime, 18 * 60 * 60, type(uint32).max));

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_CutOffTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_AuctionCutoffTimeTooLow(uint32 halfLifeTime, uint32 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 2 * 60 + 1, 8 * 60 * 60));
        cutoffTime = uint32(bound(cutoffTime, 0, 1 * 60 * 60));

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_CutOffTooLow.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_PowerFunctionReverts(uint32 halfLifeTime, uint32 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to unacceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 2 * 60 + 1, 5 * 60));
        cutoffTime = uint32(bound(cutoffTime, 17.9 * 60 * 60, 18 * 60 * 60 - 1));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert();
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testFuzz_Success_setAuctionCurveParameters_Base(uint32 halfLifeTime, uint32 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 30 * 60, 8 * 60 * 60 - 1));
        cutoffTime = uint32(bound(cutoffTime, 1 * 60 * 60 + 1, 18 * 60 * 60 - 1));

        uint256 expectedBase = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime));

        // Given: the owner is the users.creatorAddress
        vm.startPrank(users.creatorAddress);
        // When: the owner sets the discount rate
        vm.expectEmit(true, true, true, true);
        emit AuctionCurveParametersSet(uint64(expectedBase), cutoffTime);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();

        // Then: the discount rate is correctly set
        assertEq(liquidator.getBase(), expectedBase);
    }

    function testFuzz_Success_setAuctionCurveParameters_cutoffTime(uint32 halfLifeTime, uint32 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        halfLifeTime = uint32(bound(halfLifeTime, 30 * 60, 8 * 60 * 60 - 1));
        cutoffTime = uint32(bound(cutoffTime, 1 * 60 * 60 + 1, 18 * 60 * 60 - 1));

        // Given: the owner is the users.creatorAddress
        vm.prank(users.creatorAddress);
        // When: the owner sets the max auction time
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);

        // Then: the max auction time is set
        assertEq(liquidator.getCutoffTime(), cutoffTime);
    }
}
